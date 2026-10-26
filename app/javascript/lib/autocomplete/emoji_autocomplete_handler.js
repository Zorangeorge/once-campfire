import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import { loadEmojiCatalog } from "lib/emoji/catalog"

// Shortcodes start a word, so "10:30" and "Note:" don't trigger. Suggestions need two characters,
// one of them a letter or +/-, so ":)" and ":30" don't open a list that would take over Enter.
const SHORTCODE = "[a-z0-9_+\\-]"
const SHORTCODE_QUERY = new RegExp(`^:(?=.*[a-z+\\-])(${SHORTCODE}{2,})$`, "i")
const COMPLETED_SHORTCODE = new RegExp(`(?:^|[\\s\\uFFFC]):(${SHORTCODE}+):$`, "i")
const SUGGESTION_LIMIT = 8

export default class extends BaseAutocompleteHandler {
  #catalog

  constructor(element) {
    super(element)
    this.element.addEventListener("beforeinput", this.#convertAfterTypedColon)
  }

  destroy() {
    this.element.removeEventListener("beforeinput", this.#convertAfterTypedColon)
    super.destroy()
  }

  get pattern() {
    return SHORTCODE_QUERY
  }

  get commitsOnSpace() {
    return false
  }

  shouldAutocompleteWithContentAndPosition() {
    return !this.#editor.attributeIsActive("code")
  }

  getSuggestionsIdentifier() {
    return `${this.element.id}_emoji_suggestions`
  }

  getOffsetsAtPosition(position) {
    return this.#editor.getClientRectAtPosition(position) || {}
  }

  fetchResultsForQuery(query, callback) {
    loadEmojiCatalog().then(catalog => {
      this.#catalog = catalog
      callback(this.#renderSuggestions(catalog.search(query, { limit: SUGGESTION_LIMIT })))
    })
  }

  willCommitValueAtRangeWithTerminator(shortcode, range, terminator) {
    const emoji = this.#catalog?.findByShortcode(shortcode)
    if (emoji) this.#replace(range, emoji.character + terminator)
  }

  // Only a typed colon converts, so undoing a conversion or pasting ":smile:" keeps the text
  #convertAfterTypedColon = ({ data }) => {
    if (data === ":") setTimeout(this.#convertCompletedShortcode)
  }

  #convertCompletedShortcode = async () => {
    if (!this.#shortcodeBeforeCursor) return

    const catalog = await loadEmojiCatalog()
    const shortcode = this.#shortcodeBeforeCursor
    const emoji = shortcode && catalog.findByShortcode(shortcode)

    if (emoji) {
      const [ position ] = this.#editor.getSelectedRange()
      this.#replace([ position - shortcode.length - 2, position ], emoji.character)
    }
  }

  get #shortcodeBeforeCursor() {
    const [ start, end ] = this.#editor.getSelectedRange()
    if (start !== end || this.#editor.attributeIsActive("code")) return

    return this.#editor.getDocument().toString().slice(0, start).match(COMPLETED_SHORTCODE)?.[1]
  }

  #replace(range, text) {
    this.#editor.recordUndoEntry("Insert emoji")
    this.#editor.setSelectedRange(range)
    this.#editor.insertString(text)
  }

  // Shortcodes are limited to SHORTCODE characters when the data is generated, so they're safe in HTML
  #renderSuggestions(emoji) {
    return emoji.map(({ character, shortcode }) => `
      <suggestion-option class="autocomplete__item flex align-center gap unpad" role="option" value="${shortcode}">
        <span class="autocomplete__btn btn btn--borderless btn--transparent min-width flex-item-grow justify-start">
          <span class="emoji-suggestion__character" aria-hidden="true">${character}</span>
          <span class="autocompletable__name">:${shortcode}:</span>
        </span>
      </suggestion-option>
    `).join("")
  }

  get #editor() {
    return this.element.editor
  }
}

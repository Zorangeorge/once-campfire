import { Controller } from "@hotwired/stimulus"
import { loadEmojiCatalog } from "lib/emoji/catalog"
import { isTouchDevice } from "helpers/navigator_helpers"

export default class extends Controller {
  static targets = [ "search", "categories", "list", "results", "groups" ]

  #catalog

  async toggle() {
    if (this.element.open) {
      // On touch devices this would pop the keyboard up over the picker
      if (!isTouchDevice()) this.searchTarget.focus()
      await this.#load()
    } else {
      this.#clearSearch()
    }
  }

  close() {
    this.element.open = false
    this.dispatch("close")
  }

  closeOnClickOutside({ target }) {
    if (this.element.open && !this.element.contains(target)) {
      this.element.open = false
    }
  }

  search() {
    if (!this.#catalog) return

    const query = this.searchTarget.value.trim()
    if (query) this.resultsTarget.replaceChildren(this.#renderResults(this.#catalog.search(query)))

    this.resultsTarget.hidden = !query
    this.groupsTarget.hidden = !!query
    this.listTarget.scrollTop = 0
  }

  pick(event) {
    const button = event.target.closest("[data-character]")
    if (button) this.#pick(button.dataset.character, { keepOpen: event.shiftKey })
  }

  pickFirst(event) {
    if (event.isComposing) return

    event.preventDefault()
    const [ first ] = this.#visibleButtons
    if (first) this.#pick(first.dataset.character)
  }

  jumpTo({ params: { group } }) {
    this.#clearSearch()
    this.listTarget.scrollTop = this.groupsTarget.children[group].offsetTop - this.listTarget.offsetTop
  }

  navigate(event) {
    if (!event.key.startsWith("Arrow")) return
    event.stopPropagation() // Up would otherwise start editing your last message

    const button = event.target.closest("[data-character]")
    if (button) {
      event.preventDefault()
      const next = this.#neighbour(button, event.key) || this.searchTarget
      next.focus()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.#visibleButtons[0]?.focus()
    }
  }

  async #load() {
    if (this.#catalog) return

    this.#catalog = await loadEmojiCatalog()
    this.#render()
    this.search()
  }

  #pick(character, { keepOpen = false } = {}) {
    this.dispatch("pick", { detail: { character } })
    if (!keepOpen) this.element.open = false
  }

  #clearSearch() {
    if (this.searchTarget.value) {
      this.searchTarget.value = ""
      this.search()
    }
  }

  #neighbour(button, key) {
    const buttons = this.#visibleButtons
    const index = buttons.indexOf(button)

    switch (key) {
      case "ArrowLeft": return buttons[index - 1]
      case "ArrowRight": return buttons[index + 1]
      case "ArrowUp": return closestInNextRow(button, buttons.slice(0, index).reverse())
      case "ArrowDown": return closestInNextRow(button, buttons.slice(index + 1))
    }
  }

  #render() {
    const { groups } = this.#catalog

    this.categoriesTarget.replaceChildren(...groups.map(({ name, emoji }, index) => element("button", {
      type: "button", class: "emoji-picker__category", title: name, "aria-label": name,
      "data-action": "emoji-picker#jumpTo", "data-emoji-picker-group-param": index
    }, emoji[0].character)))

    this.groupsTarget.replaceChildren(...groups.map(({ name, emoji }) => this.#renderSection(name, emoji)))
  }

  #renderResults(emoji) {
    const section = this.#renderSection("Search results", emoji)
    if (!emoji.length) section.append(element("p", { class: "emoji-picker__status txt-small" }, "No emoji found"))
    return section
  }

  #renderSection(name, emoji) {
    const section = element("section", { "aria-label": name })
    const grid = element("div", { class: "emoji-picker__grid" })

    grid.append(...emoji.map(({ character, name, shortcode }) => element("button", {
      type: "button", class: "emoji-picker__emoji", tabindex: "-1", title: `${name} :${shortcode}:`, "aria-label": name, "data-character": character
    }, character)))

    section.append(element("h3", { class: "emoji-picker__group-name txt-small" }, name), grid)
    return section
  }

  get #visibleButtons() {
    const container = this.resultsTarget.hidden ? this.groupsTarget : this.resultsTarget
    return [ ...container.querySelectorAll("[data-character]") ]
  }
}

// Rows wrap wherever the grid's width puts them, so compare positions rather than indexes
function closestInNextRow(button, candidates) {
  const { top, left } = button.getBoundingClientRect()
  const positioned = candidates.map(candidate => ({ candidate, rect: candidate.getBoundingClientRect() }))
  const nextRowTop = positioned.find(({ rect }) => Math.abs(rect.top - top) > 1)?.rect.top

  return positioned
    .filter(({ rect }) => Math.abs(rect.top - nextRowTop) < 1)
    .sort((a, b) => Math.abs(a.rect.left - left) - Math.abs(b.rect.left - left))[0]?.candidate
}

function element(tagName, attributes, text) {
  const element = document.createElement(tagName)
  Object.entries(attributes).forEach(([ name, value ]) => element.setAttribute(name, value))
  if (text) element.textContent = text
  return element
}

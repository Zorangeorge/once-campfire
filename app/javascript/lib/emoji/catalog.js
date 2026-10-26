import { drawableEmoji } from "lib/emoji/support"

let catalog

// The data is ~50 KB gzipped, so it's only fetched the first time it's needed
export function loadEmojiCatalog() {
  catalog ||= import("emoji-data")
    .then(({ default: groups }) => new EmojiCatalog(groups))
    .catch(error => {
      catalog = null
      throw error
    })

  return catalog
}

class EmojiCatalog {
  #byShortcode = new Map
  #visible

  constructor(data) {
    const groups = data.map(({ name, emoji }) => ({ name, emoji: emoji.map(row => new Emoji(row)) }))
    const all = groups.flatMap(({ emoji }) => emoji)
    const drawable = drawableEmoji(all)

    all.forEach(emoji => emoji.shortcodes.forEach(shortcode => this.#byShortcode.set(shortcode, emoji)))
    this.#visible = all.filter(drawable)
    this.groups = groups
      .map(({ name, emoji }) => ({ name, emoji: emoji.filter(drawable) }))
      .filter(({ emoji }) => emoji.length)
  }

  // Includes emoji this device can't draw, since the people reading the message may
  findByShortcode(shortcode) {
    return this.#byShortcode.get(shortcode.toLowerCase())
  }

  search(query, { limit = Infinity } = {}) {
    query = query.trim().toLowerCase()
    if (!query) return []

    const terms = query.split(/\s+/)

    return this.#visible
      .map((emoji, index) => ({ emoji, index, rank: emoji.rankFor(query, terms) }))
      .filter(({ rank }) => rank)
      .sort((a, b) => a.rank[0] - b.rank[0] || a.rank[1] - b.rank[1] || a.index - b.index)
      .slice(0, limit)
      .map(({ emoji }) => emoji)
  }
}

class Emoji {
  constructor([ character, name, shortcodes, keywords, version ]) {
    this.character = character
    this.name = name
    this.shortcodes = shortcodes.split(" ")
    this.version = version

    const shortcodeParts = this.shortcodes.flatMap(code => [ code, ...code.split(/[_-]/) ])
    this.words = [ ...new Set([ ...shortcodeParts, ...`${name} ${keywords}`.toLowerCase().split(/\s+/) ]) ]
  }

  get shortcode() {
    return this.shortcodes[0]
  }

  // [ tier, shortcode length ]: exact shortcode, then shortcode prefix, then every term prefixing a word
  rankFor(query, terms) {
    if (this.shortcodes.includes(query)) return [ 0, 0 ]

    const prefixed = this.shortcodes.filter(code => code.startsWith(query))
    if (prefixed.length) return [ 1, Math.min(...prefixed.map(code => code.length)) ]

    if (terms.every(term => this.words.some(word => word.startsWith(term)))) {
      return [ this.name.split(" ").some(word => word.startsWith(terms[0])) ? 2 : 3, 0 ]
    }
  }
}

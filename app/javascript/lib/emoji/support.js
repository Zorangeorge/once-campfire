// Emoji fonts lag behind Unicode (Windows 10 stops at Emoji 12 and has no flags). A color emoji
// draws the same pixels in any fill color, while a missing one is drawn in the fill color.

const FONT = `16px "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", "Twemoji Mozilla", sans-serif`
const REFERENCE_EMOJI = "😀"
const COUNTRY_FLAG = /^\p{Regional_Indicator}{2}$/u
const ZERO_WIDTH_JOINER = "‍"

export function drawableEmoji(allEmoji) {
  // Privacy protections add noise to canvas reads, which would hide everything
  if (!canDraw(REFERENCE_EMOJI)) return () => true

  const version = newestDrawableVersion(allEmoji)
  const flags = canDraw("🇯🇵")

  return emoji => emoji.version <= version && (flags || !COUNTRY_FLAG.test(emoji.character))
}

function newestDrawableVersion(allEmoji) {
  const samples = new Map
  allEmoji.forEach(emoji => {
    if (!samples.has(emoji.version) && !COUNTRY_FLAG.test(emoji.character)) samples.set(emoji.version, emoji.character)
  })

  const newestFirst = [ ...samples.keys() ].sort((a, b) => b - a)
  return newestFirst.find(version => canDraw(samples.get(version))) ?? 0
}

function canDraw(character) {
  const black = drawn(character, "#000")
  const white = drawn(character, "#fff")
  return black.some(Boolean) && black.every((value, index) => value === white[index]) && drawsAsOneGlyph(character)
}

function drawn(character, color) {
  const context = canvasContext()
  context.clearRect(0, 0, 32, 32)
  context.fillStyle = color
  context.fillText(character, 0, 0)
  return context.getImageData(0, 0, 32, 32).data
}

// Joined sequences the font lacks draw as their parts side by side
function drawsAsOneGlyph(character) {
  if (!character.includes(ZERO_WIDTH_JOINER)) return true

  const context = canvasContext()
  return context.measureText(character).width < context.measureText(REFERENCE_EMOJI).width * 1.5
}

let context
function canvasContext() {
  if (!context) {
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = 32
    context = canvas.getContext("2d", { willReadFrequently: true })
    context.font = FONT
    context.textBaseline = "top"
  }
  return context
}

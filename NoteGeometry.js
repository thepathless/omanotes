.pragma library

// Pure helpers shared by Panel.qml. Kept free of QML state so the docking
// maths and contrast rule can be reasoned about (and tested) on their own.

function clamp(value, min, max) {
  if (max < min) return min
  return Math.max(min, Math.min(max, value))
}

function clampX(x, width, screenWidth, gap) {
  if (screenWidth <= 0) return Math.round(x)
  return Math.round(clamp(x, gap, screenWidth - width - gap))
}

function clampY(y, height, screenHeight, gap) {
  if (screenHeight <= 0) return Math.round(y)
  return Math.round(clamp(y, gap, screenHeight - height - gap))
}

// Top-left corner for a note docked to the bar widget that opened it.
// Mirrors KeyboardPanel.cardOrigin: the parallel axis follows the icon, the
// perpendicular axis uses the painted bar thickness so internal bar padding
// never leaks into the result.
function dockedPosition(args) {
  var barPosition = args.barPosition || "top"
  var gap = Number(args.gap) || 0
  var screenWidth = Number(args.screenWidth) || 0
  var screenHeight = Number(args.screenHeight) || 0
  var barThickness = Number(args.barThickness) || 0
  var cardWidth = Number(args.cardWidth) || 0
  var cardHeight = Number(args.cardHeight) || 0

  // No live widget (first paint, hotkey before the bar loads): centre on the
  // bar edge so the note still opens in a sensible place.
  var anchorWidth = Number(args.anchorWidth) || 0
  var anchorHeight = Number(args.anchorHeight) || 0
  var anchorX = Number(args.anchorX)
  var anchorY = Number(args.anchorY)
  if (!args.hasAnchor) {
    if (barPosition === "left" || barPosition === "right") {
      anchorY = screenHeight / 2
    } else {
      anchorX = screenWidth / 2
    }
  }

  var x = 0
  var y = 0
  if (barPosition === "bottom") {
    x = anchorX + anchorWidth / 2 - cardWidth / 2
    y = screenHeight - barThickness - cardHeight - gap
  } else if (barPosition === "left") {
    x = barThickness + gap
    y = anchorY + anchorHeight / 2 - cardHeight / 2
  } else if (barPosition === "right") {
    x = screenWidth - barThickness - cardWidth - gap
    y = anchorY + anchorHeight / 2 - cardHeight / 2
  } else {
    x = anchorX + anchorWidth / 2 - cardWidth / 2
    y = barThickness + gap
  }

  return {
    x: clampX(x, cardWidth, screenWidth, gap),
    y: clampY(y, cardHeight, screenHeight, gap)
  }
}

// Perceived luminance (sRGB coefficients) of a QML color. QML colors expose
// r/g/b in 0..1.
function isLightColor(color) {
  if (!color) return false
  var r = Number(color.r)
  var g = Number(color.g)
  var b = Number(color.b)
  if (isNaN(r) || isNaN(g) || isNaN(b)) return false
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.55
}

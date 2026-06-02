# paintutils API Documentation

Utility library for drawing graphics: pixels, lines, boxes, and images.

> **Warning:** All draw functions may change the cursor position and current background color.

## Functions

### parseImage(image) → table
Parses an image from a multi-line string (raw NFP format).
```lua
local image = paintutils.parseImage([[
 e  e

e    e
 eeee
]])
paintutils.drawImage(image, term.getCursorPos())
```

### loadImage(path) → table | nil
Loads an NFP image from a file (compatible with the `paint` program). Returns nil if file doesn't exist.

### drawPixel(xPos, yPos [, colour])
Draws a single pixel. Defaults to current background color.

### drawLine(startX, startY, endX, endY [, colour])
Draws a straight line.
```lua
paintutils.drawLine(2, 3, 30, 7, colors.red)
```

### drawBox(startX, startY, endX, endY [, colour])
Draws the outline of a box.

### drawFilledBox(startX, startY, endX, endY [, colour])
Draws a filled box.

### drawImage(image, xPos, yPos)
Draws an image loaded by `parseImage` or `loadImage`.

# Window API Documentation

Creates terminal redirects occupying a bounded region within a parent terminal — useful for split-screen UIs and buffered displays.

## Main Function

### window.create(parent, nX, nY, nWidth, nHeight [, bStartVisible]) → Window
Creates a window within a parent terminal.
- `parent`: term.Redirect (use `term.current()` or `term.native()`, not `term` directly)
- `nX`, `nY`: Position in parent
- `nWidth`, `nHeight`: Size
- `bStartVisible?`: Defaults to true

## Window Methods

### Display
- `write(sText)`
- `blit(sText, sTextColor, sBackgroundColor)`
- `clear()`
- `clearLine()`
- `scroll(n)`

### Cursor
- `getCursorPos()` → x, y
- `setCursorPos(x, y)`
- `setCursorBlink(blink)`
- `getCursorBlink()` → boolean
- `restoreCursor()` — sync parent cursor to window position

### Color
- `setTextColor/setTextColour(color)`
- `getTextColor/getTextColour()` → number
- `setBackgroundColor/setBackgroundColour(color)`
- `getBackgroundColor/getBackgroundColour()` → number
- `setPaletteColor/setPaletteColour(colour, r, g, b)`
- `getPaletteColor/getPaletteColour(colour)` → r, g, b
- `isColor/isColour()` → boolean

### Window State
- `getSize()` → width, height
- `setVisible(visible)`
- `isVisible()` → boolean
- `redraw()` — force redraw to screen
- `getLine(y)` → text, textColors, backgroundColors

### Positioning
- `getPosition()` → x, y
- `reposition(new_x, new_y [, new_width, new_height [, new_parent]])`

## Notes
Windows buffer their content even if the parent is cleared. Multiple windows can share one parent and overlap. Multishell uses this pattern — each tab gets a full-screen window, only one visible at a time.

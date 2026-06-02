# Monitor Peripheral Documentation

## Overview

Monitors are in-world display blocks that function as terminal redirects. They support the same methods as terminals plus monitor-specific functions. Both standard (monochrome) and advanced (color) varieties exist.

**Key Features:**
- Act as terminal redirects (use with `term.redirect()`)
- Trigger `monitor_resize` events when resized
- Advanced monitors support `monitor_touch` events when right-clicked

## Methods

### Text Scale

**`setTextScale(scale)`** — Adjusts display scale (0.5 to 5, multiples of 0.5).

**`getTextScale()`** → number

### Cursor Control

**`getCursorPos()`** → x, y

**`setCursorPos(x, y)`**

**`getCursorBlink()`** → boolean

**`setCursorBlink(blink)`**

### Text Output

**`write(text)`** — Writes at cursor, does not wrap.

**`scroll(y)`** — Shifts content up/down.

**`blit(text, textColour, backgroundColour)`** — Per-character colors using hex digits.

### Display Management

**`getSize()`** → width, height

**`clear()`**

**`clearLine()`**

### Color Functions

**`getTextColour()` / `getTextColor()`** → number

**`setTextColour(colour)` / `setTextColor(colour)`**

**`getBackgroundColour()` / `getBackgroundColor()`** → number

**`setBackgroundColour(colour)` / `setBackgroundColor(colour)`**

**`isColour()` / `isColor()`** → boolean

### Palette Customization

**`setPaletteColour(index, colour)` / `setPaletteColor(...)`** — 24-bit RGB int or r,g,b channels (0-1).

**`getPaletteColour(colour)` / `getPaletteColor(colour)`** → r, g, b (0-1)

## Example

```lua
local monitor = peripheral.find("monitor")
monitor.setCursorPos(1, 1)
monitor.write("Hello, world!")
```

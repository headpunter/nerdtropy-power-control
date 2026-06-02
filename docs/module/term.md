# Term API Documentation

## Overview

The `term` API allows interaction with a computer's terminal or monitors for displaying text and ASCII graphics in ComputerCraft.

## Core Functions

### Text Output

**write(text)**
- Writes text at the current cursor position, advancing the cursor to the end
- Does not handle line breaks or word wrapping

**blit(text, textColour, backgroundColour)**
- Writes text with specific foreground and background colors per character
- All three strings must be equal length
- Each character is a hexadecimal color digit (0-f)

### Cursor Management

**getCursorPos()** → x (number), y (number)

**setCursorPos(x, y)**
- Sets cursor location for subsequent writes

**getCursorBlink()** → boolean

**setCursorBlink(blink)**
- Toggles cursor blinking

### Screen Management

**getSize()** → width (number), height (number)

**clear()**
- Clears terminal with current background color

**clearLine()**
- Clears current line with current background color

**scroll(y)**
- Shifts all content up/down by y lines (negative reverses direction)

### Color Control

**setTextColour(colour)** / **setTextColor(colour)**
- Sets foreground color using a `colors` API constant

**getTextColour()** / **getTextColor()** → number

**setBackgroundColour(colour)** / **setBackgroundColor(colour)**
- Sets background fill color

**getBackgroundColour()** / **getBackgroundColor()** → number

**isColour()** / **isColor()** → boolean
- Whether terminal supports color (grayscale if not)

### Palette Management

**setPaletteColour(index, colour)** or **setPaletteColour(index, r, g, b)**
- Customizes how a color displays; 24-bit RGB int or separate r,g,b channels (0-1)

**getPaletteColour(colour)** → r (number), g (number), b (number)
- Values in 0-1 range

**nativePaletteColour(colour)** → r, g, b
- Returns default palette values without modifications

### Terminal Redirection

**redirect(target)** → previous Redirect
- Redirects all term output to a monitor, window, or custom terminal object

**current()** → Redirect
- Returns current terminal object

**native()** → Redirect
- Returns native terminal (not recommended for multitasked environments)

## Redirect Type

Any terminal-like object implementing the term API methods. Includes monitors and windows.

## Notes

- American and British spelling variants exist for all color functions
- The `colors`/`colours` APIs provide color constants
- Use `term.redirect()` to write to monitors

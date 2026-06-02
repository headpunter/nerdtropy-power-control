# Colors API Documentation

## Overview

Constants and functions for working with color values in CC: Tweaked. British spelling alias: `colours`.

## Color Constants

| Constant | Value | Blit char | Default Hex |
|----------|-------|-----------|-------------|
| `white` | 1 | 0 | #F0F0F0 |
| `orange` | 2 | 1 | #F2B233 |
| `magenta` | 4 | 2 | #E57FD8 |
| `lightBlue` | 8 | 3 | #99B2F2 |
| `yellow` | 16 | 4 | #DEDE6C |
| `lime` | 32 | 5 | #7FCC19 |
| `pink` | 64 | 6 | #F2B2CC |
| `gray` | 128 | 7 | #4C4C4C |
| `lightGray` | 256 | 8 | #999999 |
| `cyan` | 512 | 9 | #4C99B2 |
| `purple` | 1024 | a | #B266E5 |
| `blue` | 2048 | b | #3366CC |
| `brown` | 4096 | c | #7F664C |
| `green` | 8192 | d | #57A64E |
| `red` | 16384 | e | #CC4C4C |
| `black` | 32768 | f | #111111 |

## Functions

### combine(...) → number
Combines a set of colors into a larger set (union).
```lua
colors.combine(colors.white, colors.magenta, colors.lightBlue) -- => 13
```

### subtract(colors, ...) → number
Removes colors from an initial set.
```lua
colors.subtract(colors.lime, colors.orange, colors.white) -- => 32
```

### test(colors, color) → boolean
Tests whether `color` is contained within `colors`.
```lua
colors.test(colors.combine(colors.white, colors.magenta), colors.magenta) -- => true
```

### packRGB(r, g, b) → number
Combines RGB channels (0-1 each) into a hex color value.
```lua
colors.packRGB(0.7, 0.2, 0.6) -- => 0xb23399
```

### unpackRGB(rgb) → r, g, b
Separates a hex color into r, g, b channels (0-1 each).
```lua
colors.unpackRGB(0xb23399) -- => 0.7, 0.2, 0.6
```

### toBlit(color) → string
Converts a color to its blit hex character (0-9a-f).
```lua
colors.toBlit(colors.red) -- => "e"
```

### fromBlit(hex) → number
Converts a blit hex character to a color value.
```lua
colors.fromBlit("e") -- => 16384
```

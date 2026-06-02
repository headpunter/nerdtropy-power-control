# GPS Module Documentation

## Overview

The GPS module enables computers and turtles to determine their location using modems by communicating with GPS host computers via trilateration.

## Constants

### CHANNEL_GPS = 65534
The broadcast channel used for GPS requests and responses.

## Functions

### locate([timeout [, debug]]) → x, y, z | nil
Retrieves the current computer or turtle's location.

**Parameters:**
- `timeout?` (number, default: 2) — Max seconds to wait
- `debug?` (boolean, default: false) — Enable debug output

**Returns:** Three numbers (x, y, z) on success, or `nil` if position cannot be established.

**Example:**
```lua
local x, y, z = gps.locate(2, false)
if x then
  print("Location: " .. x .. ", " .. y .. ", " .. z)
else
  print("GPS signal not found")
end
```

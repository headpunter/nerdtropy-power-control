# _G (Global Environment) Documentation

Functions in the global environment defined in `bios.lua`. Standard Lua functions are not included.

## Functions

### sleep(time)
Pauses execution for a specified duration in seconds. Rounded up to nearest 0.05-second increment. Events during sleep are discarded.

**Parameters:** `time` (number) — Duration in seconds

**Example:**
```lua
sleep(3)
```

### write(text)
Outputs text without a newline, with automatic text wrapping.

**Parameters:** `text` (string)
**Returns:** number — Lines written

### print(...)
Displays values separated by spaces, with wrapping and trailing newline.

**Returns:** number — Lines written

### printError(...)
Outputs values in red text with wrapping and newline.

### read([replaceChar [, history [, completeFn [, default]]]])
Captures user keyboard input with history, completion, and masking support.

**Parameters:**
- `replaceChar?` (string) — Display character instead of typed input (e.g., `"*"` for passwords)
- `history?` (table) — Previous entries accessible via arrow keys; oldest at index 1
- `completeFn?` (function) — Takes partial input, returns completion suggestions
- `default?` (string) — Pre-populated text

**Returns:** string — User-entered text

**Example (password):**
```lua
write("Password> ")
local pwd = read("*")
```

## Variables

### _HOST
ComputerCraft and Minecraft version string.
Example: `ComputerCraft 1.93.0 (Minecraft 1.15.2)`

### _CC_DEFAULT_SETTINGS
Default computer settings from mod config as comma-separated key=value string.
Example: `shell.autocomplete=false,lua.autocomplete=false`

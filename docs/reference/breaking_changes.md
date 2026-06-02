# Breaking Changes Between Versions

## CC:T 1.109.0 to 1.109.3

**Lua 5.2 Update:**
- `arg` pseudo-argument removed; use `...` for varargs
- Environments use `_ENV`; `getfenv`/`setfenv` only work with functions that have an `_ENV` upvalue
- `string.dump` removed
- `math.random` uses Lua 5.4 generator

**Data Handling:**
File handles, HTTP requests, and websockets now pass raw bytes without UTF-8 conversion.

## Minecraft 1.13

**Key Codes:**
Key codes for `key`/`key_up` events changed (LWJGL 3). Use `keys` API constants, not hardcoded numbers. Numpad Enter now differs from Enter.

**Block/Item Changes:**
- `turtle.inspect()` no longer returns metadata
- `turtle.getItemDetail()` no longer returns damage
- Wool is now 16 separate items instead of one with color variants

**Data Packs:**
Custom ROMs use data packs (not resource packs). File names must be lowercase.

**Turtle Behavior:**
Turtles can exist in waterlogged blocks and pass through water sources.

## CC:T 1.88.0

Unlabeled computers/turtles retain IDs when broken — they no longer stack with identical items.

## ComputerCraft 1.80pr1

`shell.run` programs run in isolated environments — globals don't leak between programs. Programs with `/` in the name are only searched in the current directory.

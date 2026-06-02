# Lua 5.2/5.3 Feature Compatibility

CC:T uses Cobalt (Lua 5.2 base) with selected Lua 5.3 additions.

## Lua 5.2 — Supported

- `goto` and labels
- `_ENV`
- String escapes: `\z`, `\xNN`
- Hex literal fractions and exponents
- `__len`, `__pairs` metamethods
- `bit32` library
- Enhanced `load` with mode parameter
- `rawlen`, negative `select` indexing
- `xpcall` arguments
- `table.pack`, `table.unpack`
- `math.log` with base
- File `*L` read mode

## Lua 5.2 — NOT Supported

- `collectgarbage` options
- `__ipairs` metamethod
- `loadstring`, `getfenv`, `setfenv`
- `string.dump` with upvalues
- Various `os` functions

## Lua 5.3 — Supported

- Unicode escapes `\u{XXX}`
- `utf8` library
- `coroutine.isyieldable`
- `string.pack`, `string.unpack`, `string.packsize`
- `table.move`
- Metamethod respect in table operations and `ipairs`

## Lua 5.3 — NOT Supported

- Integer subtypes
- Bitwise operators (`&`, `|`, `~`, `<<`, `>>`, `//`)
- Floor division `//`
- `math.frexp`, `math.ldexp`, `math.pow`, trig hyperbolics, integer boundary constants

## Additional

- Lua 5.0 deprecated: `string.gfind`, `table.getn`
- Lua 5.5: `table.create`

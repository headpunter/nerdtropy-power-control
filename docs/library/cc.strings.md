# cc.strings Documentation

String and text manipulation utilities. New in 1.95.0.

## Functions

### wrap(text [, width]) → {string}
Wraps text so each line fits within a width. Defaults to terminal width.
Useful for monitors and printers without relying on `print`.

### ensure_width(line [, width]) → string
Creates a fixed-width string by truncating or padding with spaces.

### split(str, deliminator [, plain=false [, limit]]) → {string}
Splits a string by a delimiter.
- `plain`: if true, treats delimiter as literal text (not a Lua pattern)
- `limit`: max number of elements in result

```lua
-- Split by whitespace
cc.strings.split("This is a sentence.", "%s+")
-- Split literally, max 3 parts
cc.strings.split("a-b-c-d", "-", true, 3)
```

**Note:** `split` added in 1.112.0.

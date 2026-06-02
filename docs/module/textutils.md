# textutils API Documentation

## Overview

Utilities for formatting strings, serialization, JSON handling, and code completion.

## Functions

### Text Output

**slowWrite(text [, rate])**
- Writes text character-by-character; default 20 chars/sec. No newline.

**slowPrint(sText [, nRate])**
- Prints text character-by-character with newline.

**formatTime(nTime [, bTwentyFourHour])** → string
- Converts `os.time()` value to readable format (e.g., "6:30 PM")

**pagedPrint(text [, free_lines])** → number
- Prints with pagination; prompts when output exceeds screen size.

**tabulate(...)**
- Displays data in columnar format. Accepts alternating color codes and row tables.

**pagedTabulate(...)**
- Like tabulate but with pagination prompts.

### Serialization

**serialize(t [, opts])** / **serialise(t [, opts])** → string
- Converts Lua objects to text. Options: `compact`, `allow_repetitions`.
- Throws on functions or circular references (unless `allow_repetitions` set).

**unserialize(s)** / **unserialise(s)** → any
- Deserializes text back to Lua objects. Returns nil if invalid.

### JSON Handling

**serializeJSON(t [, opts])** / **serialiseJSON(...)** → string
- Converts Lua values to JSON. Options: `nbt_style`, `unicode_strings`, `allow_repetitions`.

**unserializeJSON(s [, options])** / **unserialiseJSON(...)** → any, string|nil
- Parses JSON to Lua objects. Options: `nbt_style`, `parse_null`, `parse_empty_array`.

### Utilities

**urlEncode(str)** → string
- Escapes characters for safe URL/POST use.

**complete(sSearchText [, tSearchTable])** → table
- Code completion for partial expressions. Appends "." for tables, "(" for functions.

## Special Values

**empty_json_array**
- Represents an empty JSON array (distinct from empty object).

**json_null**
- Represents JSON null value.

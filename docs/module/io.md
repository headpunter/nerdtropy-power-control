# IO Library Documentation

Emulates Lua's standard file I/O functionality.

## Global Variables

- **stdin**: File handle for standard input; reading prompts user input
- **stdout**: File handle for standard output
- **stderr**: File handle for error stream output

## Core Functions

### `io.open(filename [, mode])` → handle | nil, string
Opens a file. Modes: `r` (read), `w` (write), `a` (append), `r+` (update), `w+` (update+erase). Append `b` for binary.

### `io.close([file])`
Closes the provided handle, defaulting to current output file.

### `io.flush()`
Flushes buffered output from current output file.

### `io.read(...)` 
Reads from current input file.

### `io.write(...)`
Writes to current output file.

### `io.input([file])` → handle
Gets or sets current input file; accepts handle or path.

### `io.output([file])` → handle
Gets or sets current output file; accepts handle or path.

### `io.lines([filename, ...])` → iterator
Opens file and returns iterator yielding each line. Uses current input if no filename given.

### `io.type(obj)` → string | nil
Returns `"file"`, `"closed file"`, or `nil`.

## File Handle Methods

**`Handle:close()`** → true | nil, string

**`Handle:read(...)`** — Formats: `l` (line), `L` (line+newline), `a` (rest), `n` (number)

**`Handle:write(...)`** → handle | nil, string

**`Handle:flush()`**

**`Handle:seek([whence [, offset]])` → number** — `whence`: `set`, `cur`, `end`

**`Handle:lines(...)`** → iterator

# cc.pretty Documentation

A pretty printer for rendering data structures with optimal layout.

## Basic Documents

- **empty** — Empty document
- **space** — Single space
- **line** — Line break (becomes empty when grouped)
- **space_line** — Line break (becomes space when grouped)

## Functions

### text(text [, colour]) → Doc
Creates a document from a string with optional color.

### concat(...) → Doc
Joins documents or strings together.

### nest(depth, doc) → Doc
Indents subsequent lines by `depth` spaces.

### group(doc) → Doc
Formats on one line if space permits, otherwise normal layout.

### write(doc [, ribbon_frac=0.6])
Displays document on terminal without newline.

### print(doc [, ribbon_frac=0.6])
Displays document on terminal with newline.

### render(doc [, width [, ribbon_frac=0.6]]) → string
Converts document to string without displaying.

### pretty(obj [, options]) → Doc
Converts arbitrary objects to formatted documents.
- `options.function_args` (boolean)
- `options.function_source` (boolean)

### pretty_print(obj [, options [, ribbon_frac=0.6]])
Shorthand for `print(pretty(obj))`.

## Examples

```lua
local pretty = require "cc.pretty"
pretty.pretty_print({ 1, 2, 3 })

pretty.print(pretty.group(
  pretty.text("hello") .. pretty.space_line .. pretty.text("world")
))
```

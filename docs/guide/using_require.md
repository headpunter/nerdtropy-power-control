# Reusing Code with require

## Creating a Library

Create `more_term.lua`:

```lua
local function reset()
  term.clear()
  term.setCursorPos(1, 1)
end

local function write_center(text)
  local x, y = term.getCursorPos()
  local width, height = term.getSize()
  term.setCursorPos(math.floor((width - #text) / 2) + 1, y)
  term.write(text)
end

return { reset = reset, write_center = write_center }
```

Pattern: define functions locally, return a table of the public ones.

## Using the Library

```lua
local more_term = require("more_term")
more_term.reset()
more_term.write_center("Hello, world!")
```

## Module Resolution

`require` searches paths like `?.lua`, `?/init.lua`, `/rom/modules/main/?.lua`.
For `require("my.fancy.library")` it looks for `my/fancy/library.lua`.

Paths are relative to the current program's directory.

## Notes
- Libraries can return anything: a table, function, or string
- Use `cc.require.make(env, dir)` to create isolated require instances for custom shells

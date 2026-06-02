# cc.shell.completion Documentation

Helpers for shell command completion with `shell.setCompletionFunction`. New in 1.85.0.

## Helper Functions

### file(shell, text) → {string}
Completes file names relative to cwd.

### dir(shell, text) → {string}
Completes directory names relative to cwd.

### dirOrFile(shell, text, previous [, add_space]) → {string}
Completes files or directories.

### program(shell, text) → {string}
Completes program names.

### programWithArgs(shell, text, previous, starting) → {string}
Completes program arguments, delegating to the program's own completion. New in 1.97.0.

## Wrapper Functions (for use with `build`)
- **help** — wraps `help.completeTopic`
- **choice** — wraps `cc.completion.choice`
- **peripheral** — wraps `cc.completion.peripheral`
- **side** — wraps `cc.completion.side`
- **setting** — wraps `cc.completion.setting`
- **command** — wraps `cc.completion.command`

## build(...)
Combines per-argument completion functions into one handler for `shell.setCompletionFunction`.

Each argument = one program argument:
- `nil` — no completion
- `function` — called with (shell, string, previous)
- `table` — `{function, ...options}`. Use `many=true` on last to handle remaining args.

```lua
local completion = require "cc.shell.completion"
local complete = completion.build(
  { completion.choice, { "get", "put" } },
  completion.dir,
  { completion.file, many = true }
)
shell.setCompletionFunction("example.lua", complete)
```

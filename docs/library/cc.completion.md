# cc.completion Module Documentation

Helper methods for `_G.read` input completion. New in 1.85.0.

See `cc.shell.completion` for shell-specific helpers.

## Functions

### choice(text, choices [, add_space]) → {string}
Completes from a list of strings.
```lua
local completion = require "cc.completion"
local animals = { "dog", "cat", "lion", "unicorn" }
read(nil, nil, function(text) return completion.choice(text, animals) end)
```

### peripheral(text [, add_space]) → {string}
Completes the name of an attached peripheral.
```lua
read(nil, nil, completion.peripheral)
```

### side(text [, add_space]) → {string}
Completes a computer side name.

### setting(text [, add_space]) → {string}
Completes a setting name.

### command(text [, add_space]) → {string}
Completes a Minecraft command name.

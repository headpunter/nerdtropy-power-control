# cc.require Documentation

Pure Lua implementation of `require` and the `package` library. Automatically injected into every program's environment, but can be manually instantiated for custom shells. New in 1.88.0.

## Functions

### make(env, dir) → require, package
Constructs a fresh `require` function and `package` library.

**Parameters:**
- `env` (table): Environment where packages will be loaded
- `dir` (string): Base directory for resolving package paths

**Returns:** require function, package table

## Example

```lua
local r = require "cc.require"
local env = setmetatable({}, { __index = _ENV })
env.require, env.package = r.make(env, "/")

local r2 = env.require "cc.require"
print(r, r2)
```

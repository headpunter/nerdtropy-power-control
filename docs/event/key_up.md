# key_up Event

Fires when a key is released (or when the terminal closes while a key is held).

## Return Values
1. `"key_up"` (string)
2. key (number) — key code (use `keys` API constants)

## Example
```lua
while true do
    local _, key = os.pullEvent("key_up")
    print((keys.getName(key) or "unknown") .. " was released")
end
```

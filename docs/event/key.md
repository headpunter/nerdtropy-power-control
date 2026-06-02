# key Event

Fires when a key is pressed while the terminal has focus.

## Return Values
1. `"key"` (string)
2. key (number) — key code (use `keys` API constants, not raw numbers)
3. is_held (boolean) — true if held, false if newly pressed

## Notes
- For text input, use the `char` event instead
- When a printable key is pressed, `key` fires first, then `char`

## Example
```lua
while true do
    local _, key, held = os.pullEvent("key")
    print(keys.getName(key), "held=" .. tostring(held))
end
```

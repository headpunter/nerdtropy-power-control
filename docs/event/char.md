# char Event

Fires when a character is typed. Different from `key` — some keys produce no character, some key combinations produce one character.

## Return Values
1. `"char"` (string)
2. character (string) — the typed character

## Example
```lua
while true do
    local _, ch = os.pullEvent("char")
    print(ch .. " was pressed")
end
```

## Notes
Use `char` for text input, `key` for raw key presses (non-printable keys, modifiers, etc.).

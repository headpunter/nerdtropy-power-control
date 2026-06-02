# term_resize Event

Fires when the main terminal is resized (e.g., multishell tab bar shown/hidden, monitor redirect resized).

## Return Values
1. `"term_resize"` (string)

## Notes
Parts of the terminal may have moved or been deleted. Simple programs can ignore this; GUI programs should redraw the entire screen.

## Example
```lua
while true do
    os.pullEvent("term_resize")
    local w, h = term.getSize()
    print("Resized to " .. w .. "x" .. h)
    -- redraw your UI here
end
```

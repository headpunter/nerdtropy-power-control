# mouse_click Event

Fires when the terminal is clicked on an advanced computer, turtle, or pocket computer.

## Return Values
1. `"mouse_click"` (string)
2. button (number) — 1=left, 2=right, 3=middle
3. x (number) — horizontal position
4. y (number) — vertical position

## Example
```lua
while true do
    local _, button, x, y = os.pullEvent("mouse_click")
    print(("button=%d at %d,%d"):format(button, x, y))
end
```

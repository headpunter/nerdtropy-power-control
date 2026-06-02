# monitor_touch Event

Fires when an Advanced Monitor is right-clicked.

## Return Values
1. `"monitor_touch"` (string)
2. side (string) — side or network ID of the monitor
3. x (number) — horizontal position (character units)
4. y (number) — vertical position (character units)

## Example
```lua
while true do
    local _, side, x, y = os.pullEvent("monitor_touch")
    print(("monitor %s touched at %d,%d"):format(side, x, y))
end
```

# timer Event

Fires when a timer started with `os.startTimer` expires.

## Return Values
1. `"timer"` (string)
2. id (number) — the timer ID returned by `os.startTimer`

## Example
```lua
local timer_id = os.startTimer(2)
local event, id
repeat
    event, id = os.pullEvent("timer")
until id == timer_id
print("Timer fired: " .. id)
```

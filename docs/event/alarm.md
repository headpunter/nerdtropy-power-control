# alarm Event

Fires when an alarm set with `os.setAlarm()` reaches its scheduled time.

## Return Values
1. `"alarm"` (string)
2. id (number) — the alarm ID from `os.setAlarm`

## Example
```lua
local alarm_id = os.setAlarm(os.time() + 0.05)
local event, id
repeat
    event, id = os.pullEvent("alarm")
until id == alarm_id
print("Alarm fired: " .. id)
```

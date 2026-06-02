# task_complete Event

Fires when an asynchronous task (e.g., `commands.execAsync`) finishes.

## Return Values
1. `"task_complete"` (string)
2. id (number) — task ID
3. ok (boolean) — whether it succeeded
4. err (string) — error message if failed
5. ...returns — return values on success

## Example
```lua
local taskID = commands.execAsync("say Hello")
local event
repeat
    event = {os.pullEvent("task_complete")}
until event[2] == taskID
if event[3] then
    print("Success:", table.unpack(event, 4))
else
    print("Failed: " .. event[4])
end
```

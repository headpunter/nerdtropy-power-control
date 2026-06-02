# computer_command Event

Fires when `/computercraft queue` is run targeting this command computer.

## Return Values
1. `"computer_command"` (string)
2. ...args (string...) — arguments passed to the command

## Example
```lua
while true do
    local event = {os.pullEvent("computer_command")}
    print("Received:", table.unpack(event, 2))
end
```

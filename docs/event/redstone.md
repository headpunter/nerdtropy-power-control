# redstone Event

Fires whenever any redstone input changes on the computer or relay peripheral.

## Return Values
1. `"redstone"` (string)

## Example
```lua
while true do
    os.pullEvent("redstone")
    print("Redstone input changed!")
    -- Read specific sides with redstone.getInput()
end
```

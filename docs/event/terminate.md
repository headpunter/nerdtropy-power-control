# terminate Event

Fires when Ctrl+T is held. Normally handled by `os.pullEvent` (which terminates the program). Use `os.pullEventRaw` to catch it manually.

## Return Values
1. `"terminate"` (string)

## Notes
- Fires even when a filter is provided to `os.pullEventRaw`
- Always check event type when filtering with `os.pullEventRaw`

## Example (custom cleanup)
```lua
while true do
    local event = os.pullEventRaw()
    if event == "terminate" then
        print("Shutting down gracefully...")
        -- cleanup here
        return
    end
end
```

# rednet_message Event

Fires when data is received via rednet. Generated internally by `rednet.run` from a `modem_message` event.

## Return Values
1. `"rednet_message"` (string)
2. sender (number) — ID of the transmitting computer
3. message (any) — the data sent
4. protocol (string | nil) — optional protocol identifier

## Example
```lua
while true do
    local _, sender, message, protocol = os.pullEvent("rednet_message")
    print(("from=%d proto=%s msg=%s"):format(sender, tostring(protocol), tostring(message)))
end
```

## Notes
Always accompanied by a preceding `modem_message` event. Use `rednet.receive()` for higher-level handling with filtering and timeout.

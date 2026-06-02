# modem_message Event

Fires when a message is received on an open channel.

## Return Values
1. `"modem_message"` (string)
2. side (string) — which side the modem is on
3. channel (number) — channel the message arrived on
4. replyChannel (number) — sender's reply channel
5. message (any) — the transmitted data
6. distance (number | nil) — blocks between sender and receiver; nil for cross-dimensional

## Example
```lua
local modem = peripheral.find("modem") or error("No modem", 0)
modem.open(0)
while true do
    local _, side, ch, reply, msg, dist = os.pullEvent("modem_message")
    print(("ch=%d reply=%d dist=%s msg=%s"):format(ch, reply, tostring(dist), tostring(msg)))
end
```

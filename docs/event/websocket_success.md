# websocket_success Event

Fires when an async WebSocket connection (`http.websocketAsync`) succeeds.

## Return Values
1. `"websocket_success"` (string)
2. url (string) — the WebSocket URL
3. handle (http.Websocket) — the connection handle

## Example
```lua
local myURL = "wss://example.tweaked.cc/echo"
http.websocketAsync(myURL)
local event, url, handle
repeat
    event, url, handle = os.pullEvent("websocket_success")
until url == myURL
handle.send("Hello!")
print(handle.receive())
handle.close()
```

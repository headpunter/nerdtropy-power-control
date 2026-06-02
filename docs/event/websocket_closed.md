# websocket_closed Event

Fires when an open WebSocket connection closes.

## Return Values
1. `"websocket_closed"` (string)
2. url (string) — the WebSocket URL that closed
3. reason (string | nil) — server-provided close reason per RFC 6455, or nil for abnormal closure
4. code (number | nil) — RFC 6455 status code, or nil for abnormal closure

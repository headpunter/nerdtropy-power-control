# http_success Event

Fires when an async HTTP request (via `http.request()`) completes successfully.

## Return Values
1. `"http_success"` (string)
2. url (string) — the requested URL
3. response (http.Response) — the response object

## Example
```lua
local myURL = "https://tweaked.cc/"
http.request(myURL)
local event, url, handle
repeat
    event, url, handle = os.pullEvent("http_success")
until url == myURL
print(handle.readAll())
handle.close()
```

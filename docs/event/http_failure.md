# http_failure Event

Fires when an async HTTP request fails.

## Return Values
1. `"http_failure"` (string)
2. url (string) — the requested URL
3. err (string) — error description
4. response (http.Response | nil) — present only if connection succeeded but server returned an error status

## Example
```lua
local myURL = "https://does.not.exist.tweaked.cc"
http.request(myURL)
local event, url, err
repeat
    event, url, err = os.pullEvent("http_failure")
until url == myURL
print("Failed: " .. err)
```

# http_check Event

Fires when a URL verification from `http.checkURLAsync()` completes.

## Return Values
1. `"http_check"` (string)
2. url (string) — the checked URL
3. ok (boolean) — whether the URL is allowed
4. err (string | nil) — error message if not allowed

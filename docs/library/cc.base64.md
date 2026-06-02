# cc.base64 Module Documentation

Base64 encoding and decoding. New in 1.119.0.

## Functions

### encode(str [, alt_chars="+/"]) → string
Encodes binary data to Base64.
- `alt_chars`: 2-char string for 62nd/63rd bits. Use `"-_"` for URL-safe base64url.

```lua
local base64 = require "cc.base64"
print(base64.encode("Hello, world!"))
```

### decode(str [, alt_chars="+/"]) → string | nil, string
Decodes Base64 back to binary. Returns nil + error on failure.
- Input must be valid Base64 with proper trailing padding.

```lua
print(base64.decode("SGVsbG8sIHdvcmxk"))
```

# HTTP API Documentation

## Overview

The HTTP module enables making web requests and managing websocket connections in ComputerCraft. It provides both synchronous and asynchronous methods for communicating with remote servers.

## Functions

### get(...)
Makes a synchronous HTTP GET request.

**Parameters:**
- `url` (string): The target URL
- `headers?` (table): Optional header key-value pairs
- `binary?` (boolean, default: false): Whether to open response in binary mode

**Alternative syntax:** Accepts a table with fields: `url`, `headers`, `binary`, `method`, `redirect`, `timeout`

**Returns:**
- On success: A Response object
- On failure: `nil`, error message string, and optional Response object

### post(...)
Makes a synchronous HTTP POST request.

**Parameters:**
- `url` (string): The target URL
- `body` (string): Request body content
- `headers?` (table): Optional headers
- `binary?` (boolean, default: false): Binary mode flag

**Alternative syntax:** Accepts a table with fields: `url`, `body`, `headers`, `binary`, `method`, `redirect`, `timeout`

**Returns:** Same as `get()`

### request(...)
Makes an asynchronous HTTP request. Returns immediately; queues `http_success` or `http_failure` events upon completion.

**Parameters:**
- `url` (string): Target URL
- `body?` (string): Optional body (triggers POST if provided)
- `headers?` (table): Optional headers
- `binary?` (boolean, default: false): Binary mode flag

**Table form accepts:** `url`, `body`, `headers`, `binary`, `method`, `redirect`, `timeout`

### checkURLAsync(url)
Asynchronously validates whether a URL can be requested.

**Parameters:**
- `url` (string): The URL to validate

**Returns:**
- `true` if valid (check `http_check` event for permission details)
- `false` and error message if invalid

### checkURL(url)
Synchronously validates a URL.

**Parameters:**
- `url` (string): The URL to check

**Returns:**
- `true` if valid and requestable
- `false` and reason string if invalid

### websocketAsync(...)
Asynchronously opens a websocket connection. Queues `websocket_success` or `websocket_failure` events.

**Parameters:**
- `url` (string): WebSocket URL (ws:// or wss://)
- `headers?` (table): Optional connection headers

**Table form accepts:** `url`, `headers`, `timeout`

### websocket(...)
Synchronously opens a websocket connection.

**Parameters:**
- `url` (string): WebSocket URL
- `headers?` (table): Optional headers

**Table form accepts:** `url`, `headers`, `timeout`

**Returns:**
- Websocket object on success
- `false` and error message on failure

---

## Types

### Response

Represents an HTTP response with file-like read methods.

#### Methods

**getResponseCode()** → code (number), message (string)
- Returns HTTP status code and message (e.g., 200, "OK")

**getResponseHeaders()** → table
- Returns response headers as key-value pairs; multiple headers with the same name are comma-separated

### Websocket

Manages bidirectional WebSocket communication.

#### Methods

**receive([timeout])** → message (string), binary (boolean)
- Waits for a server message
- `timeout?` (number): Seconds to wait before timing out
- Returns `nil` and reason string on failure or timeout

**send(message [, binary])**
- Sends a message to the server
- `message` (string): Content to send
- `binary?` (boolean): Whether to send as binary

**close()**
- Terminates the connection

**getResponseHeaders()** → table
- Returns handshake response headers as key-value pairs

---

## Usage Example

```lua
local response = http.get("https://example.tweaked.cc")
print(response.readAll())
response.close()
```

WebSocket example:

```lua
local ws = assert(http.websocket("wss://example.tweaked.cc/echo"))
ws.send("Hello!")
print(ws.receive())
ws.close()
```

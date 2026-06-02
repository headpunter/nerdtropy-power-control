# Modem Peripheral Documentation

## Overview

Modems enable message transmission between computers across distances. They operate on numbered channels (0-65535). The `rednet` API offers a higher-level interface built on top of modems.

## Modem Types

**Wireless Modems**: 64-block range, increasing to max 384 blocks above y=96.

**Ender Modems**: No distance limitations; work across dimensions.

**Wired Modems**: Connect via networking cable; also attach additional peripherals.

## Core Methods

### Channel Management

**`open(channel)`**
- Opens a listening channel (0-65535)
- Up to 128 channels open simultaneously
- Throws if out of range or limit exceeded

**`isOpen(channel)`** → boolean

**`close(channel)`**
- Closes a channel to stop receiving messages

**`closeAll()`**
- Closes all open channels

### Transmission

**`transmit(channel, replyChannel, payload)`**
- Sends messages on a specific channel
- `channel` (number): Transmission channel
- `replyChannel` (number): Channel for responses
- `payload` (any): Primitives and tables only
- Channel need not be open to transmit

### Modem Type Detection

**`isWireless()`** → boolean
- true if wireless, false if wired

## Wired Modem Methods

*Available only on wired modems*

**`getNamesRemote()`** → table of peripheral names

**`isPresentRemote(name)`** → boolean

**`getTypeRemote(name)`** → string or nil

**`hasTypeRemote(name, type)`** → boolean or nil

**`getMethodsRemote(name)`** → table of method names or nil

**`callRemote(remoteName, method, ...)`** → method return values

**`getNameLocal()`** → string or nil
- This computer's network identifier

## Events

Messages trigger `modem_message` event with: event name, side, channel, reply channel, message, distance.

## Example

```lua
local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(43)
modem.transmit(15, 43, "Hello, world!")

local event, side, channel, replyChannel, message, distance
repeat
  event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
until channel == 43

print("Received a reply: " .. tostring(message))
```

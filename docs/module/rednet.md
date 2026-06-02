# Rednet API Documentation

Rednet provides a high-level communication layer for computers using modems in CC: Tweaked. It abstracts away modem complexity while enabling message passing between networked machines.

## Constants

**CHANNEL_BROADCAST = 65535**
The channel designated for broadcast messaging to all rednet devices.

**CHANNEL_REPEAT = 65533**
The channel used internally for repeating messages across the network.

**MAX_ID_CHANNELS = 65500**
The number of channels reserved for individual computer IDs. IDs at or above this limit wrap around to zero.

## Core Functions

### open(modem)
Activates a modem for rednet communication. The modem listens on two channels: one matching the computer's ID and the broadcast channel.

**Parameters:**
- `modem` (string) - The peripheral name of the modem to activate

**Throws:** Error if the specified modem doesn't exist

### close([modem])
Deactivates rednet on a specified modem or all open modems if none is specified.

**Parameters:**
- `modem` (string, optional) - Peripheral name to close; if omitted, closes all

**Throws:** Error if the modem doesn't exist

### isOpen([modem])
Checks whether rednet is active.

**Parameters:**
- `modem` (string, optional) - Specific modem to check

**Returns:** Boolean indicating active status

### send(recipient, message [, protocol])
Transmits a message to a specific computer ID.

**Parameters:**
- `recipient` (number) - Target computer ID
- `message` - Data to send (primitives, tables)
- `protocol` (string, optional) - Protocol label for filtering

**Returns:** Boolean indicating transmission success

### broadcast(message [, protocol])
Sends a message to every rednet-connected device on the network.

**Parameters:**
- `message` - Data to transmit
- `protocol` (string, optional) - Protocol label

### receive([protocol_filter [, timeout]])
Waits for an incoming rednet message with optional filtering and timeout.

**Parameters:**
- `protocol_filter` (string, optional) - Only accept messages with this protocol
- `timeout` (number, optional) - Maximum seconds to wait

**Returns:**
- On success: sender ID, message content, protocol string
- On timeout: nil

## Service Discovery

### host(protocol, hostname)
Registers this computer as offering a particular service. Other computers can locate it via lookup operations.

**Parameters:**
- `protocol` (string) - Service type identifier
- `hostname` (string) - Human-readable name

**Throws:** Error if hostname is reserved (like "localhost") or already in use

### unhost(protocol)
Stops advertising a previously hosted protocol.

**Parameters:**
- `protocol` (string) - Service type to deregister

### lookup(protocol [, hostname [, timeout=2]])
Searches the network for computers hosting a specific protocol.

**Parameters:**
- `protocol` (string) - Service type to find
- `hostname` (string, optional) - Specific computer name
- `timeout` (number, optional) - Default 2 seconds for responses

**Returns:**
- Without hostname: multiple computer IDs as a list
- With hostname: single computer ID or nil

## Background Process

### run()
Manages modem event conversion into rednet messages. This executes automatically at startup and shouldn't be called manually.

## Security Note

Rednet doesn't provide any guarantees about security. Other computers could be listening in to your messages, or even pretending to send messages from other computers. Consider encrypting sensitive communications on untrusted networks.

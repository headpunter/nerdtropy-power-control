# OS API Documentation

The `os` API provides functions for interacting with the current computer in CC: Tweaked.

## Functions

### loadAPI(path) [Deprecated]
Use `require` instead. Loads the given API into the global environment.

**Parameters:** `path` (string) - The path of the API to load
**Returns:** boolean - Whether the API loaded successfully

### unloadAPI(name) [Deprecated]
Removes an API previously loaded with `loadAPI`.

**Parameters:** `name` (string) - The name of the API to unload

### pullEvent([filter])
Pauses execution and waits for events matching the optional filter. Automatically terminates on "terminate" event.

**Parameters:** `filter?` (string) - Event name to filter for
**Returns:** string (event name), any (additional event parameters)

### pullEventRaw([filter])
Like `pullEvent`, but allows handling "terminate" events directly without stopping execution.

**Parameters:** `filter?` (string) - Event name to filter for
**Returns:** string (event name), any (additional event parameters)

### sleep(time)
Pauses execution for the specified seconds. Time rounds up to nearest 0.05 second increment.

**Parameters:** `time` (number) - Seconds to sleep

### version()
Returns the current CraftOS version string (e.g., "CraftOS 1.9").

**Returns:** string

### run(env, path, ...)
Executes a program at the specified path with a given environment and arguments.

**Parameters:** `env` (table), `path` (string), `...` arguments
**Returns:** boolean - Whether execution succeeded

### queueEvent(name, ...)
Adds a custom event to the queue.

**Parameters:** `name` (string), `...` event parameters (primitives and tables only)

### startTimer(time)
Starts a timer that fires after the specified seconds, generating a "timer" event.

**Parameters:** `time` (number) - Seconds until firing
**Returns:** number - Timer ID
**Throws:** If time is negative

### cancelTimer(token)
Stops a timer started with `startTimer`.

**Parameters:** `token` (number) - Timer ID to cancel

### setAlarm(time)
Sets an alarm at a specific in-game time [0.0, 24.0), generating an "alarm" event.

**Parameters:** `time` (number) - In-game time for alarm
**Returns:** number - Alarm ID
**Throws:** If time is out of range

### cancelAlarm(token)
Stops an alarm started with `setAlarm`.

**Parameters:** `token` (number) - Alarm ID to cancel

### shutdown()
Immediately shuts down the computer.

### reboot()
Immediately reboots the computer.

### getComputerID() / computerID()
Returns the computer's unique ID number.

**Returns:** number

### getComputerLabel() / computerLabel()
Returns the computer's label or nil if unset.

**Returns:** string | nil

### setComputerLabel([label])
Sets the computer's label.

**Parameters:** `label?` (string) - New label, or nil to clear

### clock()
Returns the computer's uptime in seconds.

**Returns:** number

### time([locale])
Returns the current time [0.0, 24.0) based on locale: "ingame" (default), "utc", or "local". Can also convert a date table to UNIX timestamp.

**Parameters:** `locale?` (string | table)
**Returns:** number (hour of day) or UNIX timestamp if table provided

### day([locale])
Returns the day count based on locale: "ingame", "utc", or "local".

**Parameters:** `locale?` (string)
**Returns:** number

### epoch([locale])
Returns milliseconds since epoch. "ingame" = world creation, "utc"/"local" = Jan 1 1970.
In-game time advances at 72,000 ms per real second. One Minecraft day = 86,400,000 ms.

**Parameters:** `locale?` (string)
**Returns:** number

### date([format [, time]])
Formats a timestamp using C's strftime format, or as a table with `"*t"`. Prefix with `!` for UTC.

**Parameters:** `format?` (string), `time?` (number)
**Returns:** string or table

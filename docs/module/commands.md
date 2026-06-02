# Commands API Documentation

Enables execution of Minecraft commands from a Command computer. Exclusive to Command computers.

## Core Functions

### exec(command) → boolean, {string}, number|nil
Executes a command synchronously.
- Returns: success, output lines, affected object count (nil if failed)

```lua
commands.exec("setblock ~ ~1 ~ minecraft:stone")
```

### execAsync(command) → number
Executes asynchronously; returns task ID. Fires `task_complete` event on completion.

### list(...) → {string}
Lists all executable commands. Pass sub-commands for completion.

### getDimension() → string
Returns dimension identifier (e.g., "minecraft:overworld"). New in 1.119.0.

### getBlockPosition() → x, y, z
Returns this computer's coordinates.

### getBlockInfo(x, y, z [, dimension]) → table
Queries block state and NBT data. Max 4096 blocks; must be in loaded world.

### getBlockInfos(minX, minY, minZ, maxX, maxY, maxZ [, dimension]) → {table}
Gets info for multiple blocks. Indexed as `x + z*width + y*width*depth + 1`.

### getEntities(selector) → {table}
Gets entities matching a selector (e.g., `@p`, `@e[distance=..10]`).

## Utility Properties

### native
Unmodified commands API without generated helper functions.

### async
Async wrappers for all commands. Example: `commands.async.setblock("~", "~1", "~", "minecraft:stone")`

## Dynamic Methods
All Minecraft commands are available as helper methods:
`commands.say("Hi!")` → `commands.exec("say Hi!")`

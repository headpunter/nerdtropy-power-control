# Command Peripheral Documentation

Interact with a Minecraft command block. Requires `enable_command_block` in server config.

> Not the same as the `commands` API (which is for command computers).

## Methods

### getCommand() → string
Returns the command configured in the block.

### setCommand(command)
Sets the command the block will execute.

### runCommand() → boolean, string|nil
Executes the command once. Returns success status and optional error message.

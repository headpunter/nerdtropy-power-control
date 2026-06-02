# fluid_storage Generic Peripheral

Methods for tanks and other fluid storage blocks. New in 1.94.0.

## Methods

### tanks() → { table|nil... }
Returns all tanks in this fluid storage. Each occupied tank has `name` and `amount`.
Table is sparse — use `pairs()`, not `ipairs()`.

### pushFluid(toName [, limit [, fluidName]]) → number
Moves fluid from this container to another on the same wired network.
- `toName`: peripheral name as shown by wired modem
- `limit?`: max amount to move
- `fluidName?`: specific fluid to move (arbitrary if omitted)
Returns amount moved. Throws if target doesn't exist or isn't a fluid container.

### pullFluid(fromName [, limit [, fluidName]]) → number
Pulls fluid from another container into this one.
Returns amount moved. Throws if source doesn't exist or isn't a fluid container.

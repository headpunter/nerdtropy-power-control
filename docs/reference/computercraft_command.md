# The /computercraft Command

Admin command for managing running computers on a server.

## Permissions

- All players: `queue` subcommand
- Operators (multiplayer): all other commands
- Single-player without cheats: `dump`, `turn-on`, `shutdown`, `track`
- Single-player with cheats: `tp`, `view`
- LuckPerms node: `computercraft.command.NAME`

## Computer Selectors

Like Minecraft entity selectors. Predicates:
- `id=<id>` — by computer ID
- `instance=<id>` — by instance ID
- `family=<normal|advanced|command>` — by type
- `label=<label>` — by label
- `distance=<distance>` — within block radius

Shorthand: `#<id>` = `@c[id=<id>]`

## Commands

**dump** — Lists loaded computers with status/location. Targets a specific computer for detail.

**turn-on** — Powers on computers (or all if no args).

**shutdown** — Powers down computers. Useful for diagnosing CC lag.

**tp** — Teleports player to a computer.

**view** — Opens remote terminal to observe a computer.

**track** — Performance profiling.
- `track start` — begin recording
- `track stop` — display results
- `track dump` — view current metrics

**queue** — Triggers `computer_command` events on command computers (available to non-operators).

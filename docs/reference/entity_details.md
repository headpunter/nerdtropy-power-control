# Entity Details Reference

Structure returned by `commands.getEntities()`.

## Fields

- `name` (string) — namespaced entity ID (e.g., `"minecraft:creeper"`)
- `displayName` (string) — translated display name using the server's language
- `health` (number) — current health
- `maxHealth` (number) — maximum health
- `tags` (table) — set of tags, mapping tag name to `true` (added in 1.118.0)

## Example
```lua
{
    name = "minecraft:player",
    displayName = "Alex",
    health = 20,
    maxHealth = 20,
    tags = {},
}
```

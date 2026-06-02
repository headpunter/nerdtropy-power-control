# Item Details Reference

Structure returned by `turtle.getItemDetail()` and `inventory.getItemDetail()`.

## Basic (always present)
- `name` — namespaced ID (e.g., `"minecraft:dirt"`)
- `count` — stack quantity
- `nbt` — NBT hash for comparison

## Display
- `displayName` — translated item name
- `lore` — list of descriptive strings

## Stack
- `maxCount` — max stack size (typically 64)

## Tags
- `tags` — boolean map of item classifications (e.g., `minecraft:logs`)

## Item Groups
- `itemGroups` — creative tab list with `id` and `displayName`
  *(empty on Minecraft 1.19.3–1.20.3)*

## Durability
- `damage` — current damage taken
- `maxDamage` — maximum damage
- `durability` — normalized 0–1 when damaged
- `unbreakable` — boolean

## Enchantments
- `enchantments` — array of `{ name, displayName, level }`

## Potion Effects
- `potionEffects` — array of `{ name, displayName, duration (seconds), potency }`

## Map
- `mapColour` / `mapColor` — RGB hex as number. Use `colors.unpackRGB()` to split channels.

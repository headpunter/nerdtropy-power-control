# Block Details Reference

Structure returned by `turtle.inspect()` and `commands.getBlockInfo()`.

## Core Fields (always present)
- `name` — namespaced block ID (e.g., `"minecraft:farmland"`)
- `state` — table of block state properties (e.g., `{ moisture = 7 }`)

## Tags
- `tags` — table mapping tag names to `true`

```lua
local ok, block = turtle.inspect()
if ok and block.tags["minecraft:logs"] then
    print("It's a log!")
end
```

## Map Color
- `mapColour` / `mapColor` — RGB hex as a number
  Use `colors.unpackRGB()` to split into channels.

## Example
```lua
{
    name = "minecraft:farmland",
    state = { moisture = 7 },
    tags = { ["minecraft:mineable/shovel"] = true },
    mapColour = 9923917,
}
```

## Version History
- Block info: 1.64
- Block state: 1.76
- Map color: 1.117.0

# inventory Generic Peripheral

Methods for interacting with inventories. New in 1.94.0.

## Methods

### size() → number
Total number of slots in the inventory.

### list() → { table|nil... }
All items in the inventory. Each occupied slot has `name`, `count`, `nbt`.
Sparse table — use `pairs()`, not `ipairs()`.

```lua
local chest = peripheral.find("minecraft:chest")
for slot, item in pairs(chest.list()) do
  print(("%d x %s in slot %d"):format(item.count, item.name, slot))
end
```

### getItemDetail(slot) → table | nil
Full details for an item in a slot. Returns nil if empty. Throws if slot out of range.

```lua
local item = chest.getItemDetail(1)
if item then print(item.displayName, item.name) end
```

### getItemLimit(slot) → number
Max stack size for a slot (typically 64). New in 1.96.0. Throws if slot out of range.

### pushItems(toName, fromSlot [, limit [, toSlot]]) → number
Transfers items to another inventory on the same wired network. Returns items transferred.
Throws if target doesn't exist, isn't an inventory, or slots are invalid.

### pullItems(fromName, fromSlot [, limit [, toSlot]]) → number
Pulls items from another inventory on the same wired network. Returns items transferred.

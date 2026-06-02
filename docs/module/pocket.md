# Pocket API Documentation

Controls the current pocket computer's upgrades. Exclusive to pocket computers.

```lua
if pocket then
  print("On a pocket computer")
end
```

## Functions

### equipBack() → boolean, string|nil
Searches player's inventory for an upgrade and equips it. Search starts from the currently selected slot.

### unequipBack() → boolean, string|nil
Removes the current upgrade from the pocket computer.

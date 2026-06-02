# Peripheral API Documentation

## Overview

The `peripheral` module enables computers to locate and control peripherals—blocks or upgrades that can be interacted with. Examples include speakers for audio playback and monitors for text display.

## Peripheral Naming

Peripherals attached directly to a computer are named by their cardinal direction: `"bottom"`, `"top"`, `"left"`, `"right"`, `"front"`, or `"back"`. Remote peripherals connected via wired modems receive custom network names.

## Core Functions

### `getNames()`
Returns all attached peripheral names as a table of strings.

**Returns:** `{ string... }` — Names of all attached peripherals

**Version:** New in 1.51

---

### `isPresent(name)`
Checks whether a peripheral exists with the specified name.

**Parameters:**
- `name` (string) — Side or network name to check

**Returns:** `boolean` — Whether the peripheral exists

---

### `getType(peripheral)`
Retrieves the types of a named or wrapped peripheral.

**Parameters:**
- `peripheral` (string | table) — Peripheral name or wrapped instance

**Returns:** `string...` — One or more type identifiers, or `nil` if absent

**Version:** Changed in 1.88.0 to accept wrapped peripherals; 1.99 now returns multiple types

---

### `hasType(peripheral, peripheral_type)`
Determines if a peripheral matches a particular type.

**Parameters:**
- `peripheral` (string | table) — Peripheral name or wrapped instance
- `peripheral_type` (string) — Type to verify

**Returns:** `boolean | nil` — Whether the type matches, or `nil` if peripheral absent

**Version:** New in 1.99

---

### `getMethods(name)`
Lists all callable methods available on a peripheral.

**Parameters:**
- `name` (string) — Peripheral name

**Returns:** `{ string... } | nil` — Method names, or `nil` if peripheral absent

---

### `getName(peripheral)`
Retrieves the original name of a wrapped peripheral.

**Parameters:**
- `peripheral` (table) — Wrapped peripheral instance

**Returns:** `string` — The peripheral's name

**Version:** New in 1.88.0

---

### `call(name, method, ...)`
Invokes a method on a peripheral by name, passing additional arguments.

**Parameters:**
- `name` (string) — Peripheral name
- `method` (string) — Method name
- `...` (any) — Arguments for the method

**Returns:** The method's return values

**Example:** `peripheral.call("top", "open", 1)` opens channel 1 on a modem above

---

### `wrap(name)`
Returns a table with all a peripheral's methods as callable functions, eliminating the need for repeated `peripheral.call` invocations.

**Parameters:**
- `name` (string) — Peripheral name

**Returns:** `table | nil` — Method table, or `nil` if peripheral absent

**Example:**
```lua
local modem = peripheral.wrap("top")
modem.open(1)
```

---

### `find(ty [, filter])`
Locates all peripherals of a specific type and returns their wrapped tables.

**Parameters:**
- `ty` (string) — Peripheral type to search for
- `filter?` (function) — Optional predicate taking name and wrapped table, returning boolean

**Returns:** `table...` — Zero or more wrapped peripherals matching criteria

**Examples:**
```lua
local monitors = { peripheral.find("monitor") }
for _, mon in pairs(monitors) do
  mon.write("Hello")
end
```

```lua
local wireless = { peripheral.find("modem", function(name, modem)
  return modem.isWireless()
end) }
```

**Version:** New in 1.6

---

## Related Events

- **`peripheral`** — Fires when a new peripheral connects
- **`peripheral_detach`** — Fires when a peripheral disconnects

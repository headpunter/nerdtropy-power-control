# Settings API Documentation

Read and write configuration options for CraftOS and custom programs. Settings are loaded from `/.settings` on startup. `settings.set()` does not auto-persist — call `settings.save()` to write to disk.

## Functions

### define(name [, options])
Establishes a setting with optional metadata. New in 1.87.0.
- `options.description` (string)
- `options.default` (any)
- `options.type` (string): `"number"`, `"string"`, `"boolean"`, or `"table"`

### undefine(name)
Removes a setting's definition without clearing its value.

### set(name, value)
Assigns a value. Must be serializable and non-nil.

### get(name [, default]) → any
Retrieves a setting's current value. Returns default or nil if unset.

### getDetails(name) → table
Returns table with description, default, type, and current value.

### unset(name)
Resets a setting to its default.

### clear()
Resets all settings to defaults.

### getNames() → {string}
Returns all defined setting names alphabetically.

### load([path=".settings"]) → boolean
Loads settings from file, merging with existing values.

### save([path=".settings"]) → boolean
Persists all settings to file (overwrites completely).

## Example

```lua
settings.define("my.setting", {
    description = "An example setting",
    default = 123,
    type = "number",
})
print(settings.get("my.setting"))  -- 123
settings.set("my.setting", 456)
settings.save()
```

## Events
`setting_changed` — fired when a setting is modified (1.87.0+)

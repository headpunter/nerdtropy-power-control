# cc.expect Module Documentation

Validation functions for checking function arguments and table fields.

## Functions

### expect(index, value, ...) → value
Validates that an argument matches one of the specified types. Throws if not.

**Parameters:**
- `index` (number): 1-based argument position
- `value`: The argument to validate
- `...` (string): Allowed type names (e.g., `"number"`, `"string"`, `"table"`)

### field(tbl, index, ...) → value
Validates a table field matches one of the specified types. Throws if not.

**Parameters:**
- `tbl` (table)
- `index` (string): Field name
- `...` (string): Allowed types

### range(num [, min [, max]]) → num
Validates a number is within range. Throws if outside bounds.

**Parameters:**
- `num` (number)
- `min?` (number, default: -math.huge)
- `max?` (number, default: math.huge)

## Notes
- New in 1.84.0
- Since 1.96.0 the module is directly callable as `expect(index, value, ...)`

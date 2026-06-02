# CraftOS Exception Protocol

CraftOS extends Lua errors with "exceptions" — richer error objects that preserve stack traces across `pcall` and `coroutine.resume`.

## Exception Structure

An exception is a table with:
- `message` (string) — the error message
- `thread` — the thread where the error occurred
- metatable with `__name = "exception"`

## Implementation

```lua
local exception_mt = {
    __name = "exception",
    __tostring = function(self) return self.message end
}
```

Wrap string errors as exception objects before re-throwing in custom coroutine managers.

## Integration with `parallel`

`parallel` doesn't wrap exceptions by default (backward compat). To opt in, use `debug.getregistry().cc_try_barrier`:

```lua
local try_barrier = debug.getregistry().cc_try_barrier
```

Pass a context table with `co` (parent coroutine) and `can_wrap` (boolean) to signal that your manager supports exceptions. This allows `parallel` to wrap exceptions safely within your coroutine manager.

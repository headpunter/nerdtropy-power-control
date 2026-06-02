# Running Programs on Startup

## Single File

Create `/startup.lua` — it runs automatically on boot.

```lua
shell.run("my_program")
```

## Multiple Files

Place files in a `/startup/` directory — all are executed on boot.

```
/startup/settings.lua
/startup/hello.lua
```

Useful for modular initialization: settings, completion functions, background services, etc.

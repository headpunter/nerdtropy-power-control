# Parallel API Documentation

## Overview

The `parallel` API provides a mechanism for running multiple functions concurrently. Functions execute by switching between them whenever they yield (via `coroutine.yield`, `os.pullEvent`, or `os.sleep`).

Each function maintains its own copy of the event queue, so event-consuming functions can safely run in parallel without affecting each other.

**Important:** Pass function references, not calls. Use `parallel.waitForAny(myFunc)`, not `parallel.waitForAny(myFunc())`.

## Functions

### waitForAny(...)
Alternates execution of supplied functions until **one** completes. Errors propagate upward.

**Parameters:** `...` function — Functions to execute in parallel

**Example:**
```lua
local function tick()
    while true do
        os.sleep(1)
        print("Tick")
    end
end
local function wait_for_q()
    repeat
        local _, key = os.pullEvent("key")
    until key == keys.q
    print("Q was pressed!")
end
parallel.waitForAny(tick, wait_for_q)
```

### waitForAll(...)
Executes all supplied functions in parallel until **all** complete. Errors pause others and propagate.

**Parameters:** `...` function — Functions to run; each receives an optional `spawn` parameter

**Warnings:**
- Systems buffer only 256 events; excessive parallel functions can overflow the queue
- Maximum 16 concurrent HTTP requests

**Example:**
```lua
local function a()
    os.sleep(1)
    print("A is done")
end
local function b()
    os.sleep(3)
    print("B is done")
end
parallel.waitForAll(a, b)
```

**Spawning dynamically:**
```lua
parallel.waitForAll(function(spawn)
    for i = 1, 5 do
        spawn(function()
            sleep(math.random())
            print("Finished " .. i)
        end)
    end
end)
```

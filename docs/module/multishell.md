# Multishell API Documentation

Allows multiple programs to run simultaneously with tab-based navigation.

## Overview

Each process has an ID corresponding to its tab position. IDs are dynamic and change as tabs open/close. Like the shell API, multishell is injected by the shell program — not available in global scope.

## Functions

### getFocus() → number
Returns the index of the currently visible process.

### setFocus(n) → boolean
Switches display to a specified process. Returns false if process doesn't exist.

### getTitle(n) → string | nil
Retrieves the tab title for a process.

### setTitle(n, title)
Updates the tab title for a process.
```lua
multishell.setTitle(multishell.getCurrent(), "Hello")
```

### getCurrent() → number
Returns the index of the currently executing process.

### launch(tProgramEnv, sProgramPath, ...) → number
Starts a new process. Returns new process index (expires after yielding).
```lua
local id = multishell.launch({}, "/rom/programs/fun/hello.lua")
multishell.setTitle(id, "Hello!")
```

### getCount() → number
Returns total number of active processes.

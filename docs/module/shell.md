# Shell API Documentation

CraftOS command-line interface API. Not a true API — injected by the shell program.

## Execution

### execute(command, ...) → boolean
Runs a program with arguments passed verbatim.
```lua
shell.execute("paint", "my-image")
```

### run(...) → boolean
Runs a program with arguments concatenated and parsed as a command line.

### exit()
Terminates the current shell. Shuts down computer if top-level shell.

## Directory & Path

### dir() → string
Returns current working directory.

### setDir(dir)
Sets working directory. Throws if path doesn't exist or isn't a directory.

### path() → string
Returns colon-separated program search path. Default: `.:/rom/programs:/rom/programs/turtle`

### setPath(path)
Sets program search path.

### resolve(path) → string
Converts relative path to absolute.

## Program Resolution

### resolveProgram(command) → string | nil
Finds a program using path and aliases. Returns absolute path or nil.

### programs([include_hidden]) → {string}
Lists all available programs in the current path.

## Completion

### complete(sLine) → {string} | nil
Completes a shell command line.

### completeProgram(program) → {string}
Completes a program name.

### setCompletionFunction(program, complete)
Registers a completion function for a program.
Signature: `function(shell, index, argument, previous)`

### getCompletionInfo() → table
Returns all registered completion functions.

## Other

### getRunningProgram() → string
Returns absolute path of the currently executing program.

### setAlias(command, program)
Creates a command alias.

### clearAlias(command)
Removes an alias.

### aliases() → {[string]=string}
Lists all current aliases.

### openTab(...) → number
Opens a new multishell tab. Returns tab ID.

### switchTab(id)
Switches focus to a multishell tab.

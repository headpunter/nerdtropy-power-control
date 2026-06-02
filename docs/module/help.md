# help API Documentation

Manages help file discovery and retrieval.

## Functions

### path() → string
Returns colon-separated list of help search directories.

### setPath(newPath)
Sets help search directories.
```lua
help.setPath(help.path() .. ":/myfolder/help/")
```

### lookup(topic) → string | nil
Finds a help file by topic name. Returns path or nil.
```lua
help.lookup("disk")
```

### topics() → table
Returns alphabetically ordered list of all available topics.

### completeTopic(prefix) → table
Returns topic completions matching a prefix (for use with `read()`).

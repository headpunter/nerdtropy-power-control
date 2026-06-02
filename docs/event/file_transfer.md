# file_transfer Event

Fires when files are drag-and-dropped onto an open computer. New in 1.101.0.

## Return Values
1. `"file_transfer"` (string)
2. files (TransferredFiles) — container for the transferred files

## Types

### TransferredFiles
- `getFiles()` → `{TransferredFile}` — table of file objects

### TransferredFile (binary read handle)
- `getName()` → string — filename
- Standard `fs.ReadHandle` methods (read, readAll, seek, close, etc.)

## Examples

```lua
-- List transferred files
local _, files = os.pullEvent("file_transfer")
for _, file in ipairs(files.getFiles()) do
    local size = file.seek("end")
    file.seek("set", 0)
    print(file.getName() .. " (" .. size .. " bytes)")
    file.close()
end
```

```lua
-- Save transferred files
local _, files = os.pullEvent("file_transfer")
for _, file in ipairs(files.getFiles()) do
    local h = fs.open(file.getName(), "wb")
    h.write(file.readAll())
    h.close()
    file.close()
end
```

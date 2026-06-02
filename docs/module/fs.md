# fs API Documentation

## Overview

The `fs` API enables interaction with the computer's filesystem, providing capabilities for reading/writing files, manipulating paths, querying file properties, and managing directories.

## Core Functions

### File & Directory Queries

**`exists(path: string) → boolean`**
Determines whether a specified path exists.

**`isDir(path: string) → boolean`**
Checks if a path points to a directory.

**`isReadOnly(path: string) → boolean`**
Returns whether a path cannot be written to.

**`getSize(path: string) → number`**
Returns file size in bytes. Throws if path doesn't exist.

**`attributes(path: string) → table`**
Retrieves comprehensive file metadata including size, directory status, read-only flag, creation time, and modification time (in milliseconds since UNIX epoch).

### Path Manipulation

**`combine(path: string, ...: string) → string`**
Joins multiple path segments with appropriate separators. Supports relative path components like `..`.

**`getName(path: string) → string`**
Extracts the final filename component from a path.

**`getDir(path: string) → string`**
Returns the parent directory portion of a path.

### File Operations

**`open(path: string, mode: string) → handle | nil, string`**
Opens files with modes: `"r"` (read), `"w"` (write), `"a"` (append), `"r+"` (read/write), `"w+"` (read/write, erased). Append `"b"` for binary mode. Returns file handle or error message.

**`makeDir(path: string)`**
Creates directory and any missing parent directories. Throws on failure.

**`move(path: string, dest: string)`**
Relocates file/directory. Auto-creates parent directories. Throws on failure.

**`copy(path: string, dest: string)`**
Duplicates file/directory. Auto-creates parent directories. Throws on failure.

**`delete(path: string)`**
Removes file or directory (recursively deletes subdirectories).

### Directory Listing

**`list(path: string) → {string}`**
Returns table of filenames in specified directory. Throws if path doesn't exist.

**`find(path: string) → {string}`**
Searches for paths matching wildcard patterns. Supports `?` (single character) and `*` (multiple characters) within individual path segments.

**`complete(path: string, location: string, [options]) → {string}`**
Provides path completion suitable for input functions. Options include `include_files`, `include_dirs`, and `include_hidden` booleans.

### Mount Information

**`getDrive(path: string) → string | nil`**
Returns the mount name (`"hdd"` for main drive, `"rom"` for ROM, etc.). Throws if path doesn't exist.

**`isDriveRoot(path: string) → boolean`**
Checks if a path is a filesystem mount point. Throws if path doesn't exist.

**`getCapacity(path: string) → number | nil`**
Returns drive capacity in bytes, or nil for read-only drives. Throws on error.

**`getFreeSpace(path: string) → number | "unlimited"`**
Returns available space in bytes. Read-only drives return `"unlimited"`.

## File Handle Types

### ReadHandle
**Methods:**
- `read([count]) → string | number | nil` — Read bytes; count returns string, absent returns single byte
- `readAll() → string | nil` — Read entire file
- `readLine([withTrailing]) → string | nil` — Read single line
- `seek([whence, offset]) → number` — Change position ("set", "cur", "end")
- `close()` — Close file

### WriteHandle
**Methods:**
- `write(...contents)` — Write string or byte
- `writeLine(text)` — Write string with newline
- `seek([whence, offset]) → number` — Change position
- `flush()` — Save without closing
- `close()` — Close file

### ReadWriteHandle
Combines all methods from both ReadHandle and WriteHandle, enabling simultaneous reading and writing.

## Key Notes

- All functions work with absolute paths; use `shell.resolve()` for relative-to-absolute conversion
- Binary mode files operate on raw bytes rather than UTF-8 encoding
- File handles require explicit `close()` calls to ensure data persistence
- Timestamps use milliseconds since UNIX epoch; pass to `os.date()` for readable format

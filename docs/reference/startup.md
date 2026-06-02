# Computer Startup Sequence

When a computer powers on, it runs startup files in this order:

## 1. ROM Autorun (`/rom/autorun`)
All files here run first. Empty by default; can be extended via datapacks or mods.

## 2. Disk Drive Startup (if `shell.allow_disk_startup` is enabled)
Connected disks are searched. The first disk with any of the following is used:
- `startup` or `startup.lua` — executed first
- `startup/` directory — all programs executed second

Disk iteration order is undefined — don't connect multiple disks with startup files.

## 3. Root Directory (if `shell.allow_startup` is enabled)
Same search as disk drives, applied to the computer's root filesystem.

## File Ordering in Directories

`fs.list` is used, which returns files in **lexicographical order**. `startup/a.lua` always runs before `startup/b.lua`.

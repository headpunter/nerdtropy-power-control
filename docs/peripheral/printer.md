# Printer Peripheral Documentation

Outputs text to physical pages. Requires ink (dyes) and paper.

## Workflow
1. `newPage()` — begin a page
2. `setCursorPos()` / `write()` — place content
3. `endPage()` — finalize and output

## Methods

### write(text)
Writes text to the current page. Throws if no page active.

### getCursorPos() → x, y
Gets cursor position. Throws if no page active.

### setCursorPos(x, y)
Sets cursor position. Throws if no page active.

### getPageSize() → width, height
Gets page dimensions. Throws if no page active.

### newPage() → boolean
Starts a new page. Returns false if no ink or paper.

### endPage() → boolean
Finalizes current page. Returns false if tray full. Throws if no page active.

### setPageTitle([title])
Sets the page title. Throws if no page active.

### getInkLevel() → number
Returns remaining ink.

### getPaperLevel() → number
Returns remaining paper.

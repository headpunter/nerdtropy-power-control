# cc.image.nft Documentation

Read and draw NFT ("Nitrogen Fingers Text") images — a colored text image format. New in 1.90.0.

## Functions

### parse(image) → table
Parses an NFT image from a string.

### load(path) → table | nil, string
Loads an NFT image from a file. Returns nil + error message on failure.

### draw(image, xPos, yPos [, target])
Renders an NFT image at the specified position.
- `target?`: term.Redirect, defaults to current terminal

## Example

```lua
local nft = require "cc.image.nft"
local image = assert(nft.load("data/example.nft"))
nft.draw(image, term.getCursorPos())
```

# Setting up GPS

## Requirements
- 4 computers with Ender Modems (wireless modems work but have limited range)
- Always-loaded chunk (spawn chunks or chunk loader)

## Location
Pick a 10×10×10 cube. Larger areas = better accuracy at distance. Use F3+G to see chunk boundaries.

## Building the Constellation
1. Place a computer at one corner with a modem on top
2. Place computers at two adjacent corners with modems
3. Place the fourth computer directly above the first (top of the cube)

This covers all three spatial dimensions required for trilateration.

## Configuration (each computer)
1. Press F3 and note the "Targeted Block" coordinates
2. Run `edit startup.lua`
3. Enter: `shell.run("gps", "host", x, y, z)` with actual coordinates
4. Save and reboot

## Testing
Run `gps locate` on a nearby computer with a wireless modem.

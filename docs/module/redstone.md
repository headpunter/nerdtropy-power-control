# Redstone Module Documentation

The `redstone` library (also `rs`) enables interaction with redstone signals adjacent to a computer: binary, analogue, and bundled cables.

## Functions

### getSides() → {string}
Returns the six sides: "top", "bottom", "left", "right", "front", "back".

### setOutput(side, on)
Activates/deactivates a redstone signal (strength 15 when on).

### getOutput(side) → boolean
Retrieves the current output state.

### getInput(side) → boolean
Checks if redstone input is present.

### setAnalogOutput(side, value) / setAnalogueOutput(side, value)
Sets signal strength (0-15). Throws if out of range.

### getAnalogOutput(side) / getAnalogueOutput(side) → number
Gets output signal strength.

### getAnalogInput(side) / getAnalogueInput(side) → number
Gets input signal strength.

### setBundledOutput(side, output)
Sets bundled cable output using a colour bitmask.

### getBundledOutput(side) → number
Gets bundled cable output bitmask.

### getBundledInput(side) → number
Gets bundled cable input bitmask.

### testBundledInput(side, mask) → boolean
Tests if specific colours are active on a bundled cable.

## Events

Changes to redstone input trigger a `redstone` event for event-driven programming.

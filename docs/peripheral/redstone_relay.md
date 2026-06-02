# Redstone Relay Peripheral

Controls redstone signals on all six sides. Useful when paired with wired modems to control multiple redstone outputs from a single computer.

## Methods

### Digital Signals
**setOutput(side, on)** — Emit signal (strength 15) or turn off
**getOutput(side)** → boolean
**getInput(side)** → boolean

### Analog Signals
**setAnalogOutput(side, value)** / **setAnalogueOutput(side, value)** — Set strength 0-15
**getAnalogOutput(side)** / **getAnalogueOutput(side)** → number
**getAnalogInput(side)** / **getAnalogueInput(side)** → number

### Bundled Cables
**setBundledOutput(side, output)** — Set color bitmask
**getBundledOutput(side)** → number
**getBundledInput(side)** → number
**testBundledInput(side, mask)** → boolean

## Example
```lua
local relay = peripheral.find("redstone_relay")
while true do
  relay.setOutput("top", not relay.getOutput("top"))
  sleep(0.5)
end
```

# Playing Audio with Speakers

## Digital Audio Basics

Speakers in CC:T use **PCM audio** — a list of amplitude samples:
- **Sample rate:** 48,000 samples/sec (48kHz)
- **Resolution:** 8-bit, values -128 to 127
- **Max per call:** 128×1024 samples (~2.7 seconds)

## Generating a Sine Wave (220Hz)

```lua
local speaker = peripheral.find("speaker")
local buffer = {}
local t, dt = 0, 2 * math.pi * 220 / 48000
for i = 1, 128 * 1024 do
    buffer[i] = math.floor(math.sin(t) * 127)
    t = (t + dt) % (math.pi * 2)
end
speaker.playAudio(buffer)
```

## Streaming Audio

Stream in chunks to avoid memory issues. When the buffer is full, `playAudio` returns false — wait for `speaker_audio_empty`:

```lua
local speaker = peripheral.find("speaker")
local t, dt = 0, 2 * math.pi * 220 / 48000
while true do
    local buffer = {}
    for i = 1, 16 * 1024 * 8 do
        buffer[i] = math.floor(math.sin(t) * 127)
        t = (t + dt) % (math.pi * 2)
    end
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end
```

## Playing DFPWM Files

DFPWM compresses audio efficiently (1 bit/sample). Convert with music.madefor.cc or FFmpeg 5.1+.

```lua
local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local decoder = dfpwm.make_decoder()

for chunk in io.lines("data/example.dfpwm", 16 * 1024) do
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end
```

## Audio Effect: Delay (1.5s)

```lua
local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

local samples_i, samples_n = 1, 48000 * 1.5
local samples = {}
for i = 1, samples_n do samples[i] = 0 end

local decoder = dfpwm.make_decoder()
for chunk in io.lines("data/example.dfpwm", 16 * 1024) do
    local buffer = decoder(chunk)
    for i = 1, #buffer do
        local orig = buffer[i]
        buffer[i] = orig * 0.6 + samples[samples_i] * 0.4
        samples[samples_i] = orig
        samples_i = samples_i + 1
        if samples_i > samples_n then samples_i = 1 end
    end
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
    sleep(0.05)
end
```

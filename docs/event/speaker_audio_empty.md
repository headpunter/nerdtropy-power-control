# speaker_audio_empty Event

Fires when a speaker's audio buffer is empty and ready for more data. Use this to stream audio in chunks.

## Return Values
1. `"speaker_audio_empty"` (string)
2. name (string) — the speaker peripheral name

## Usage Pattern
```lua
local decoder = require("cc.audio.dfpwm").make_decoder()
local speaker = peripheral.find("speaker")
local f = fs.open("audio.dfpwm", "rb")
while true do
    local chunk = f.read(16 * 1024)
    if not chunk then break end
    local pcm = decoder(chunk)
    while not speaker.playAudio(pcm) do
        os.pullEvent("speaker_audio_empty")
    end
end
f.close()
```

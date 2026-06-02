# Speaker Peripheral Documentation

Produces audio through three methods: noteblock sounds, Minecraft sounds, or PCM audio streaming.

## Methods

### playNote(instrument [, volume [, pitch]]) → boolean
Plays a noteblock instrument. Returns false if 8-note/tick limit reached.

- `instrument`: `"harp"`, `"basedrum"`, `"snare"`, `"hat"`, `"bass"`, `"flute"`, `"bell"`, `"guitar"`, `"chime"`, `"xylophone"`, `"iron_xylophone"`, `"cow_bell"`, `"didgeridoo"`, `"bit"`, `"banjo"`, `"pling"`
- `volume?`: 0.0–3.0 (default 1.0)
- `pitch?`: 0–24 semitones (default 12)

### playSound(name [, volume [, pitch]]) → boolean
Plays a Minecraft sound effect. Returns false if another sound started this tick.

- `name`: e.g., `"minecraft:block.note_block.harp"`, `"entity.creeper.primed"`
- `volume?`: 0.0–3.0 (default 1.0)
- `pitch?`: 0.5–2.0 playback speed (default 1.0)

### playAudio(audio [, volume]) → boolean
Streams PCM audio at 48kHz. Returns false if buffer is full.

- `audio`: table of amplitudes (-128 to 127), up to 128×1024 samples
- Wait for `speaker_audio_empty` event when buffer is full

### stop()
Halts all audio playback and clears the buffer.

## Related
- `cc.audio.dfpwm` — decode DFPWM files for streaming

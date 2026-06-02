# cc.audio.dfpwm Documentation

Converts between DFPWM audio streams and PCM amplitude data.
DFPWM (Dynamic Filter Pulse Width Modulation) uses 1 bit per sample.

> **Warning:** Encoders and decoders maintain internal state per stream. Do not reuse across multiple streams.

## Functions

### make_encoder() → function(pcm) → string
Creates a stateful encoder. Input: table of amplitudes (-128 to 127). Output: DFPWM string.

### encode(input) → string
One-shot encoding of a complete audio table. Use `make_encoder()` for chunked streams.

### make_decoder() → function(dfpwm) → {number}
Creates a stateful decoder. Input: DFPWM string. Output: amplitude table (-128 to 127).

### decode(input) → {number}
One-shot decoding of a complete DFPWM string. Use `make_decoder()` for chunked streams.

## Audio Conversion
Convert standard audio to DFPWM using:
- music.madefor.cc (online)
- LionRay Wav Converter (Java)
- FFmpeg 5.1+

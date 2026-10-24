# MPV.CONFIG Creation Through Grok Bot

This is an mpv.conf for HDR OLED playback, tuned on an RTX 5070 Ti with gpu-next, Vulkan and NVDEC, feeding a 77" LG G5 calibrated to 2150 nits.

Instead of one global look, it uses auto profiles that pick processing per file from resolution, transfer (SDR or HDR), release tag and average bitrate. Each auto profile applies when its condition becomes true and is restored when it turns false (`profile-restore=copy-equal`, or `copy` for music, live streams and fullscreen), so nothing carries over from one file to the next in a playlist.

Files:

- [mpv.conf](mpv.conf): the config
- [scripts/interlace-latch.lua](scripts/interlace-latch.lua): **required**, it drives the per-file interlace latch (see Special cases)
- [scripts/sdr-screenshot.lua](scripts/sdr-screenshot.lua): optional, Ctrl+S SDR screenshot (see Extras)

## One owner per option

mpv auto profiles do not rank each other, so options that several profiles used to fight over now have exactly one owner each:

| Option | Default (global) | Changed only by |
|---|---|---|
| `target-colorspace-hint` | `no` (SDR sources do not enable source-driven HDR signaling; actual output/composition depends on the Windows HDR path) | `HDR-Output`: any PQ/HLG source, any resolution, including HDR streams |
| `interpolation`, `video-sync`, `tscale` | `no` / `audio` (24p movies) | `HFR-Motion-Stabilizer` (progressive >30 fps, not live) or `Live-Motion` (live URL, progressive), which never overlap |
| `audio-delay` | `-0.120` (headphone lip-sync) | `music`: `0` |
| `deinterlace` | off | `Interlaced-Deint-Lock` |

Deband is the one deliberately layered option: the base resolution profile sets a default and a quality tier can override `deband-*` only. Tiers are declared above their base profile and mpv evaluates auto profiles in reverse declaration order, so the tier is applied after its base. Every base and tier profile writes all of its deband fields explicitly. This layering was validated on the tested mpv build, including playlist transitions (weak to clean 1080p, weak to premium 1080p, weak to ordinary SD, weak to ordinary 4K, 1080p to interlaced to 1080p, 1080p to 60 fps to 1080p, 4K to interlaced SD to SD): every file in a playlist got the same values as when played on its own. Re-test after upgrading mpv.

## Base profiles

Resolution profiles skip cover art and still images, and live URLs.

**Native 4K** (also matches SDR 4K) uses bilinear scaling, light deband, fruit dither and no shaders, so skies and whites stay calm with no glitter. HDR 4K gets HDR output, with the renderer doing tone and gamut mapping to `target-peak` 2150 using spline tone mapping that follows each scene's measured brightness rather than the mastering metadata. SDR sources (4K or otherwise) do not enable source-driven HDR signaling here; actual output/composition behavior depends on the Windows HDR path.

**1080p** gets ewa_lanczossharp plus FSRCNNX 2x upscaling, sigmoid upscaling, ordered dither and a light deband (iterations 1, threshold 32, range 16, no added grain) so clean Blu-ray encodes keep their grain. HDR 1080p gets HDR output through the same `HDR-Output` profile as 4K.

**SD and 720p** stay deliberately plain, bilinear with no dither or shaders, because aggressive upscaling just magnifies noise, and dither on soft SD reads as shimmer on an OLED. Deband is off; its other fields are written as mpv defaults so values from an earlier 4K or 1080p file in a playlist cannot linger.

## Quality tiers

Bitrates here are the average total-file bitrate (file size x 8 / duration, so audio, subtitles and container overhead count too). It's a rough heuristic, not the video stream's bitrate.

On top of those base profiles sit quality tiers:

- **Premium:** remuxes and top encoders like FraMeSToR, r00t and WRATH, or anything over 15 Mbps, get a lighter deband to protect grain.
- **Default 1080p:** everything else, such as QxR/Tigole, scene x264 and WEB releases, gets the light 1/32/16 deband above.
- **Weak:** small public encodes like YTS, YIFY, GalaxyRG and RARBG under 8 Mbps, or anything under 3.5 Mbps, get a stronger deband plus added grain. That masks blocking but can't restore detail.
- **Weak 4K:** low-bitrate 4K re-encodes get their own light deband (under 10 Mbps, or a known small-encode group such as QxR or Tigole under 11 Mbps). The group tag must be a delimited word: preceded by a space, `[`, `(` or `-`, and followed by `)`, `]`, or `.ext` at the end of the path, so `(Tigole)`, `-Tigole.mkv` and ` Tigole.mkv` match but words inside titles do not.
- **Extras:** featurettes, deleted scenes and other bonus folders don't inherit the main movie's release tag, so they're tiered by their own bitrate.
- **TV:** episodes are detected by path (any folder starting with "TV Series") and tiered by bitrate alone.

## Special cases

- **Interlaced** sources stay deinterlaced for the whole file and are kept out of motion interpolation. `scripts/interlace-latch.lua` sets `user-data/ilace` the first time a frame of the current file is flagged interlaced and resets it on every new file. The `Interlaced-Deint-Lock` profile and the HFR check both key off that flag. Without the script, deinterlacing never turns on.
- **High frame rate** progressive content over 30 fps gets interpolation (temporal blending to smooth cadence, not frame generation) with display-resample at every resolution. Live URLs, music files and cover art are excluded.
- **Music** (FLAC, WAV, ALAC, M4A, APE, DSF) plays through WASAPI with ReplayGain, gapless playback and `audio-delay=0`, since there's no picture to lip-sync. Cover art and still images never trigger the resolution, tier, HFR or HDR profiles, so a 600x600 album cover isn't treated as an SD movie.
- **Live-Stream** matches by URL, not by whether the stream is actually live: http/https URLs whose path ends in `.m3u8`, `.mpd` or `.ts`, optionally followed by `?query` or `#fragment`. That means on-demand HLS/DASH matches too. It gets ArtCNN, KrigBilateral, adaptive-sharpen, reconnect handling, a small in-memory cache and a brightness/contrast/saturation boost (applied to every matched stream, SDR or HDR). Every resolution, tier and HFR profile skips these URLs. Local files never match.
- **Live-Motion** uses the same URL test but only for progressive streams: it adds display-resample and interpolation for smoother pans. Interlaced streams (the same per-file `user-data/ilace` latch) skip it and stay deinterlaced; Live-Stream itself still applies to them.

## Audio

Audio is tailored to Sony XM5 headphones: 5.1 and 7.1 are downmixed to stereo with speech normalization, so Windows Sonic takes over the surround, plus a -120 ms lip-sync offset for video (music resets it to 0). Skip the audio section if you have a proper surround setup.

## Extras

- Keys **7** and **8** switch picture presets (bind them in your `input.conf`):
  - **Cinema-Night** is a neutral director reset: brightness, contrast, saturation and gamma all 0.
  - **Cinema-Day** adds a mild lift: gamma 3, brightness 1, contrast and saturation 0.
  ```
  7 apply-profile Cinema-Night ; show-text "Cinema-Night"
  8 apply-profile Cinema-Day ; show-text "Cinema-Day"
  ```
- **Ctrl+S** saves a tone-mapped SDR screenshot of an HDR frame (`scripts/sdr-screenshot.lua`).
- Resume on quit, and an in-memory cache sized for big 4K remuxes over a network share: 1 GiB read-ahead, 256 MiB back-buffer, `cache-secs=300`, no disk cache.

## Shaders

Get them from their authors and put them in `~~/shaders/` (the `shaders` folder next to `mpv.conf`):

- **FSRCNNX** by igv: [igv/FSRCNN-TensorFlow releases](https://github.com/igv/FSRCNN-TensorFlow/releases). Save `FSRCNNX_x2_16-0-4-1.glsl` as `FSRCNNX_x2_16_0_4_1.glsl` (or edit the path in `mpv.conf`).
- **ArtCNN** by Artoriuz: [Artoriuz/ArtCNN](https://github.com/Artoriuz/ArtCNN), file `GLSL/ArtCNN_C4F32_DN.glsl`.
- **KrigBilateral** by igv: [gist](https://gist.github.com/igv/a015fc885d5c22e6891820ad89555637), file `KrigBilateral.glsl`.
- **adaptive-sharpen** by bacondither: [bacondither/Adaptive-sharpen](https://github.com/bacondither/Adaptive-sharpen); mpv port by igv: [gist](https://gist.github.com/igv/8a77e4eb8276753b54bb94c1c50c317e), file `adaptive-sharpen.glsl`.

## Install

Copy everything into your mpv config folder, `%APPDATA%\mpv\` on Windows or `~/.config/mpv/` on Linux and macOS:

```
mpv/
|-- mpv.conf
|-- scripts/
|   |-- interlace-latch.lua      (required)
|   `-- sdr-screenshot.lua       (optional)
`-- shaders/
    |-- FSRCNNX_x2_16_0_4_1.glsl
    |-- ArtCNN_C4F32_DN.glsl
    |-- KrigBilateral.glsl
    `-- adaptive-sharpen.glsl
```

Screenshots go to your desktop (`~~desktop/`). To see which profile fired for a file, uncomment the `log-file` line in `mpv.conf`.

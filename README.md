# Tossy

[![Platform](https://img.shields.io/badge/platform-macOS-black)](https://github.com/thatonemacosdev/tossy-macos/releases/tag/v1.3.1)
[![License](https://img.shields.io/github/license/thatonemacosdev/tossy-macos)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/thatonemacosdev/tossy-macos)](https://github.com/thatonemacosdev/tossy-macos/releases)

> Toss your files in. Toss them out in whatever format you need.

A free, native macOS utility for converting images, video, and audio without Terminal, without uploading files anywhere, and without installing Homebrew or ffmpeg yourself. Toss files in, pick a format, convert. Handles everyday formats like HEIC, MP4, and MP3 as well as RAW camera files, MKV, WebM, FLAC, animated GIFs, animated WebP, and dozens more.

Website: [thatonemacosdev.github.io/tossy-macos](https://thatonemacosdev.github.io/tossy-macos/)
Download: [v1.3.1 release](https://github.com/thatonemacosdev/tossy-macos/releases/tag/v1.3.1)

Under the hood: GPU-accelerated image processing (Metal via Core Image) and hardware video encoding (VideoToolbox via AVFoundation) where the platform supports it, falling back to a bundled `ffmpeg` for everything else.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/image.png" alt="Tossy Images tab on macOS: drag and drop HEIC, RAW, and JPEG conversion with target-size compression" /><br /><sub>Images: toss in, target-size compression</sub></td>
    <td width="50%"><img src="docs/screenshots/video.png" alt="Tossy Video tab on macOS: converting between MP4, MKV, and WebM with hardware and ffmpeg-backed encoding" /><br /><sub>Video: hardware and ffmpeg-backed formats side by side</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/audio.png" alt="Tossy Audio tab on macOS: converting MP3, FLAC, and WAV with a bitrate picker" /><br /><sub>Audio: bitrate and format picker</sub></td>
    <td width="50%"><img src="docs/screenshots/benchmark.png" alt="Tossy Benchmark tab on macOS: scoring conversion performance from 0 to 100 against a calibrated baseline" /><br /><sub>Benchmark: scored results table</sub></td>
  </tr>
</table>

## Features

- **Images**: PNG, JPEG, HEIC, TIFF, BMP, GIF, JPEG 2000, AVIF, ICO, TGA, WebP, PSD, ICNS, DDS, OpenEXR, Radiance HDR, PNM, QOI, JPEG XL, and camera RAW (CR2, CR3, NEF, ARW, DNG, and most others Apple's built-in RAW pipeline supports). Also rasterizes SVG and PDF (one image per page).
- **Video**: MP4/MOV (H.264, HEVC, ProRes 422) via hardware encode, plus MKV, WebM, AVI, FLV, MPEG, TS/MTS/M2TS, 3GP, ASF/WMV, MXF, VOB, DV, NUT, AV1, DNxHD, DNxHR, Animated GIF, and Animated WebP via ffmpeg.
- **Audio**: MP3, AAC, M4A, WAV, FLAC, ALAC, AIFF, OGG, Opus, WMA, AC3, E-AC3, CAF.
- **Compression to a target size**: set a size like `25MB` and the app searches for a quality/bitrate/resolution that fits, instead of just applying a fixed setting.
- **Presets**: save and apply custom settings across tabs.
- **Metadata control**: option to preserve original EXIF/GPS/TIFF metadata on images, or strip container metadata on audio/video.
- **Resize**: set an output width; aspect ratio is preserved.
- **Benchmark tab**: times real conversions on your machine and scores them 0-100 against a calibrated baseline.

## Building

Requires Xcode (for a full build) or the Swift toolchain from Command Line Tools (for `swift build` / `swift run` during development). No external dependencies to install, since the `ffmpeg`, `cwebp`/`dwebp`, and `cjxl`/`djxl` binaries this app needs are vendored under `Vendor/` and get bundled into the app automatically.

```
./build_app.sh
open ./Tossy.app
```

`swift build` / `swift run` also work directly for iterating on the app without packaging it.

## Why vendored binaries instead of just Core Image / AVFoundation everywhere?

Apple's frameworks cover a lot: RAW decoding, HEIC/AVIF, hardware H.264/HEVC/ProRes. But they don't touch MKV, WebM, most legacy codecs, or most audio formats. For those, this app shells out to a bundled, self-contained copy of `ffmpeg` (and the WebP and JPEG XL reference tools, since this particular ffmpeg build wasn't compiled with encoders for those). Everything under `Vendor/` was relinked with `dylibbundler` so it runs standalone, with no Homebrew or system `ffmpeg` install required on the machine running the app.

## License

The app's own code (everything outside `Vendor/`) is licensed under GPL-3.0; see `LICENSE`.

The vendored `ffmpeg` binary in `Vendor/ffmpeg/` is itself GPL-licensed (it's built with `--enable-gpl` for libx264/libx265). See `Vendor/ffmpeg/LICENSE_NOTICE.md` for details. The WebP tools (`Vendor/webp/`) and JPEG XL tools (`Vendor/jxl/`) are both BSD-licensed.

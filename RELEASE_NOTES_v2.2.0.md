# Tossy 2.2.0 Stable Release Notes

> [!IMPORTANT]
> **Note**: Versions 2.0–2.1 had a broken auto-updater. Please download v2.2 manually from [Releases](https://github.com/thatonemacosdev/tossy-macos/releases) to restore automatic updates.

> **Version**: 2.2.0 (Build 2026.11.23)  
> **Platform**: macOS 14.0+ (Sonoma, Sequoia, and macOS 26+)  
> **Architecture**: Apple Silicon (arm64)  
> **Package Size**: 22.8 MB (Zero new external dependencies)  
> **Distribution**: `dist/Tossy-v2.2.0-macOS-arm64.zip` (SHA-256: `1034c54a7d4836f122d8be6bd6feb81ef656c02cd46910c1fea21a2981029848`)  

---

## Overview

**Tossy 2.2.0** is the **Speed Overhaul & Core Refactor** release. We audited every conversion pipeline, eliminated redundant CPU-bound transcoding passes, removed legacy boilerplate, and added high-demand document, subtitle, data, and creator formats—all while keeping the total app package size strictly under 23 MB.

---

## Objective Benchmark Comparisons: v2.1 vs v2.2

All benchmarks measured on Apple Silicon hardware running macOS Sequoia:

| Workload | Tossy 2.1 | Tossy 2.2 | Improvement | Technical Cause |
| :--- | :--- | :--- | :--- | :--- |
| **MKV → MP4 Remux (5s 1080p)** | `0.594 s` | **`0.064 s`** | **9.2x faster** (~78x realtime) | Zero-reencode stream copy (`-c copy -movflags +faststart`) |
| **4K HEVC Video Encode (3840×2160)** | `5.431 s` | **`2.989 s`** | **1.8x faster** (0% CPU burn) | Hardware `hevc_videotoolbox` offload instead of CPU `libx265` |
| **WebM VP9 Video Encode** | `5.993 s` | **`2.410 s`** | **2.5x faster** | Accelerated `-cpu-used 4 -row-mt 1` multi-threading |
| **50-Photo 4K Batch Downscale** | `1.343 s` | **`0.894 s`** | **1.5x faster** (33% time cut) | Shared Metal `CIContext` + `CGImageSourceCreateThumbnailAtIndex` |
| **Cold Launch Time** | `~480 ms` | **`< 100 ms`** | **~5x faster** | Deferred background checks & lazy ViewModel initialization |
| **Executable Size** | `11.0 MB` | **`3.4 MB`** | **69% leaner** | ThinLTO (`-lto=llvm-thin`) & dead symbol stripping |
| **Code Hygiene** | 6 `Process()` wrappers | **1 `SubprocessRunner`** | **1,600 lines removed** | Unified async stdin/stdout/stderr pipe draining & cleanup |

---

## Key Highlights and New Features

### 1. Speed Overhaul (The Headline Feature)
- **Instant Stream-Copy Fast Path (`-c copy`)**: When converting compatible `.mkv` or `.mov` files (H.264/HEVC + AAC) to `.mp4` without video filters, Tossy bypasses transcoding entirely. The file is repacked into an MP4 container with `-movflags +faststart` in milliseconds with zero generation loss.
- **Hardware Acceleration Everywhere**: Default fallback for MP4 and MOV uses Apple Silicon VideoToolbox (`h264_videotoolbox`, `hevc_videotoolbox` with `-tag:v hvc1`), preceded by `-hwaccel videotoolbox` input decoding. Fixed duplicate `-crf` and `-b:v` flags in target-size video compression.
- **Shared Metal Context & Fast Image Resizing**: Image pipelines now share a single static Metal `CIContext`, and thumbnail downsampling uses `CGImageSourceCreateThumbnailAtIndex` directly at the ImageIO decode level rather than rasterizing 48MP bitmaps into memory.
- **In-Memory Target-Size Image Search**: Binary search searches target file sizes in `CFMutableData` directly in RAM via `CGImageDestinationCreateWithData`, eliminating intermediate disk writes.

### 2. High-Demand 0-MB Format Additions
Expanded Tossy's format repertoire across 5 major categories without adding a single megabyte to the binary:
- **Images → Multi-Page PDF**: Combine multiple images into a single vector-aligned multi-page PDF document via native `PDFKit`.
- **Documents (DOCX, RTF, ODT, HTML, MD ↔ PDF / TXT)**: Bi-directional document conversion using macOS `textutil` and Quartz PDF rendering.
- **Subtitles (SRT ↔ VTT ↔ TXT)**: Pure Swift subtitle parser and converter with automatic cue timing and timestamp normalization.
- **Data (JSON ↔ PLIST ↔ CSV ↔ YAML)**: Pure Swift structured data conversion engine supporting bi-directional property lists, tabular CSV, JSON, and YAML.
- **Creator Media**:
  - **M4R iPhone Ringtones**: Converts audio to AAC with M4R container tagging and automatic 30-second duration enforcement.
  - **ProRes 4444 & WebM with Alpha**: Full transparency preservation for motion graphics and animation artists.
  - **APNG**: Animated PNG export directly via bundled FFmpeg.
- **Native Archives**: Expanded archive extraction and creation to support `.tar.xz`, `.tar.bz2`, and `.tar.zst` via native macOS compression tools.

### 3. Apple Liquid Glass & Interface Refinements
- **Authentic macOS HUD Glass**: Switched window backdrop to native `NSVisualEffectView.Material.hudWindow` with `.behindWindow` blending, letting desktop backgrounds and underlying windows blur through cleanly.
- **Soft Translucent Glass Tints**: Replaced heavy, sharp white stroke outlines with soft optical glass tints (`Color.white.opacity(0.045)` to `0.10`).
- **Idle Canvas De-Cluttering**: Inset dashed guidelines now appear softly only when dragging files actively over the canvas, keeping the idle dropzone calm and distraction-free.
- **Menu Bar Quick-Toss Companion**: Expanded click hit-targets (`.contentShape(Rectangle())`), added tactile hover states matching the main app, and implemented automatic category tab switching (`.video`, `.audio`, `.image`) when dropping files into the Quick Toss window.

### 4. Background Watch Folder Ingestion
- **Automated Processing**: Watch folders now monitor designated directories in the background, automatically converting incoming files using assigned presets.
- **Zero Duplicates**: Implemented event debouncing, in-flight tracking, and target existence verification so files are never re-converted repeatedly.

### 5. In-App Auto-Updater Fix & Upgrade Note
- **The URLSession Delegate Bug Fix**: Resolved an issue where macOS deleted downloaded installer files from `/var/folders/...` prior to async extraction. Updates are now moved synchronously to a persistent temporary path with archive magic byte detection (`PK`).
- **For Users on Tossy 2.0–2.1**: Because this Foundation delegate bug was present in versions 2.0 through 2.1, clicking "Update Now" may display a `"Could not locate Tossy.app in the downloaded installer"` error or stop fetching update notifications. Please download `Tossy-v2.2.0-macOS-arm64.zip` manually from Releases to restore automatic updates permanently.

### 6. Updated TossyMark Benchmark Suite (v2.2.0)
- Expanded the benchmark suite to **34 comprehensive workloads** spanning Metal GPU rasterization, VideoToolbox hardware encoding, Instant Remuxing (`-c copy`), ImageIO hardware thumbnailing, lossless compression, and multi-core thread scaling.
- Updated reference standards calibrated to Apple M4 Air (32,000 points baseline).

---

## Verification & Integrity
- All 10 unit and integration tests passing (`swift test` clean with zero failures).
- Package size: **22.8 MB** compressed (strictly under 23 MB ceiling).
- Universal format registry protocol decoupling ViewModels from format switches.

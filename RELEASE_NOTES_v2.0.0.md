# Tossy 2.0.0 Stable Release Notes

> **Version**: 2.0.0 (Build 2026.10.20)  
> **Platform**: macOS 14.0+ (Sonoma, Sequoia)  
> **Architecture**: Apple Silicon & Universal Binary  
> **Distribution**: `dist/Tossy-2.0.0-macOS.zip` (SHA-256: `c71a972d212a8d5f1fc16bcf0a0913948d3bba96b952a51876252b660328d856`)

---

## 🌟 Overview

**Tossy 2.0.0** is the definitive, stable release of the native macOS conversion companion. Tossy 2.0.0 transforms Tossy from a multi-tab format converter into an intelligent, **dynamic file-type detecting workspace**.

Drop video, audio, images, documents, code files, or archives into Tossy, and the window seamlessly morphs to provide the exact controls, formats, and tools needed for that media type—with zero clutter and zero terminal commands.

---

## 🚀 Key Highlights & New Features

### 1. 🪟 Dynamic File-Type Detecting Window
The main window now dynamically adapts to whatever you drop onto it:
- **Video Dropped**: Morphs into **Video Only** mode. Surfaces hardware VideoToolbox (H.264, HEVC, ProRes) and FFmpeg formats (MKV, WebM, AVI, AV1, Animated GIF/WebP), CRF quality sliders, custom resolution scales, deinterlacing, and direct lossless trimming.
- **Audio Dropped**: Morphs into **Audio Only** mode. Exposes audio formats (MP3, AAC, FLAC, WAV, Opus, OGG, ALAC, AIFF), target CBR/VBR bitrate pickers (64 kbps to 320 kbps), sample rate adjustments, and EBU R128 loudness normalization DSP.
- **Images Dropped**: Morphs into **Images Only** mode. Exposes Core Image & Metal pipelines, target-size compression, quality sliders, format knobs (WebP Sharp YUV, JPEG XL effort/distance, TIFF compression), AI Background Removal, and EXIF/GPS metadata sanitization.
- **PDF Dropped**: Morphs into **PDF Studio** mode. Surfaces Burst (page-by-page extraction), Split range extraction, Merge multi-PDF binders, Quartz vector compression, and on-device Apple Vision OCR text extraction.
- **Mixed Files Dropped**: Switches to **Universal Mode** with full multi-format batch conversion and token renaming (`{name}_{date}_{res}`).
- **Adaptive Canvas Mode Bar**: Switch back to any mode or filter at any time using the mode pill switcher.

### 2. 💻 Instant Code Card Studio Drag-and-Drop
- Dropping any source code or script file into Tossy immediately intercepts and routes into **Code Card Studio**.
- **Supported Languages**: Over 25 languages supported out of the box (`.swift`, `.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.rs`, `.go`, `.rb`, `.c`, `.cpp`, `.h`, `.hpp`, `.cs`, `.java`, `.kt`, `.html`, `.css`, `.json`, `.yaml`, `.yml`, `.sh`, `.bash`, `.zsh`, `.sql`, `.md`, `.dockerfile`).
- **Features**: Generates Carbon-style presentation cards with customizable themes, drop shadows, window titlebars, line numbering, and one-click Retina PNG or SVG export.

### 3. ⚡ Launch on Startup
- Tossy can now automatically start up silently upon macOS login.
- Built using Apple’s modern `SMAppService.mainApp` API (macOS 14+), with seamless fallback handling.
- **Toggles Available**:
  - In **Settings (`⌘,`) > General > System Integration > Launch at Login**.
  - In the **Menu Bar Status Menu > Launch on Startup**.

### 4. 🛠️ Audio-Only WebM Transcoding & Subprocess Hygiene (Issue #1 Fix)
- **Problem**: Dragging an audio-only WebM file (such as Opus-in-WebM voice recordings or YouTube audio extractions) threw `"The operation could not be completed."` error because `AVAssetExportSession` does not support demuxing WebM containers or decoding Opus audio. Additionally, FFmpeg subprocesses without terminal control were subject to `SIGTTIN` signal suspensions.
- **Fix**:
  - `MediaProbe` now accurately identifies streams with audio tracks and zero video tracks (`!hasVideo && hasAudio`).
  - Container-based routing automatically routes non-Apple containers (`.webm`, `.mkv`, `.ogg`, `.opus`, etc.) to the bundled standalone FFmpeg engine instead of attempting AVFoundation export.
  - Safe audio-only conversion routes cleanly into audio targets (MP3, AAC, FLAC, WAV, M4A) and video containers (MP4, MKV) with audio streams preserved.
  - Subprocess stdin hygiene: Connected `process.standardInput = FileHandle.nullDevice` and `-nostdin` across all worker services (`LosslessVideoTrimmer`, `AudioExtractorService`, `FFmpegService`, `ArchiveService`, `BenchmarkService`) preventing background process freezing.

### 5. 📦 Complete Studio Suites
- **Media Studio**:
  - **Lossless Video Trimmer**: Zero-generation loss video trimming with packet-level stream copying (`-c copy`) when cut points align with keyframes.
  - **Audio Track Extractor**: Rip audio stems directly out of video files in original codec or transcode to MP3, WAV, or AAC.
  - **Text & Watermark Overlay**: Render dynamic lower-thirds and custom image watermarks directly onto video.
  - **Playback Speed Controller**: Smooth video speed shifting from 0.25x to 4x with audio pitch compensation (`atempo`).
- **PDF Studio**:
  - **Quartz File Size Optimization**: Compress bloated scanned documents and rich vector PDFs.
  - **Apple Vision OCR**: On-device text recognition extracting selectable text from rasterized scans.
  - **Burst & Merge**: Split PDF pages into standalone single-page documents or bind multiple PDFs into a single file.
- **Archive Studio**:
  - Create ZIP, TAR, and GZ archives directly.
  - Optional AES-256 password encryption.
  - Multi-part split volumes for email or storage constraints.

### 6. 🚀 Streamlined Distribution (No DMG Required)
- Tossy is packaged as a clean, notarization-ready ZIP archive: `Tossy-2.0.0-macOS.zip` (23 MB).
- Self-contained with bundled, relinked `ffmpeg`, `cwebp`, `dwebp`, `cjxl`, and `djxl` binaries. No Homebrew or external runtimes required.
- Hardened recursive code signing applied to all executable binaries, bundles, and dynamic libraries.

---

## 📋 Comprehensive Verification & Quality Assurance

All test pillars in the Tossy automated test suite passed with 100% success:
- **Pillar 1 (PDF Studio)**: Merge, split, burst, Quartz vector compression, and Apple Vision OCR — **PASSED**
- **Pillar 2 (Media Studio)**: Lossless trimming, audio extraction, overlays, speed modification — **PASSED**
- **Pillar 3 (Archive Studio)**: ZIP/TAR/GZ compression, AES-256 encryption, volume splitting — **PASSED**
- **Pillar 4 (Automation & Finder Integration)**: Headless CLI worker, URL scheme dispatch (`tossy://`), Quick Actions — **PASSED**
- **Pillar 5 (Regression & Bug Fixes)**: All 22/22 regression tests passed, including audio-only WebM transcoding — **PASSED**
- **Pillar 6 (V2 Polish)**: Token renaming, dynamic mode detection, drag-away chips, Code Card Studio routing — **PASSED**

---

## 📥 Installation & Gatekeeper Instructions

1. Download [`Tossy-2.0.0-macOS.zip`](https://github.com/thatonemacosdev/tossy-macos/releases/tag/v2.0.0).
2. Unzip and drag `Tossy.app` to your `/Applications` folder.
3. **Opening for the first time**:
   - Right-click (or Control-click) `Tossy.app` and choose **Open**, then click **Open** in the confirmation dialog.
   - Or open Terminal and run: `xattr -cr /Applications/Tossy.app`.

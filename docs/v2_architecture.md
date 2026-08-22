# Tossy 2.0 Titanium - Technical Architecture

Tossy 2.0 is designed as the universal macOS file workspace, built on native Apple frameworks with zero third-party cloud dependencies, 100% on-device local execution, and zero telemetry.

## Core System Architecture

### 1. Document & PDF Processing Engine
- **Frameworks**: `PDFKit`, `Vision`, `CoreGraphics`, `ImageIO`.
- **Merge & Reorder**: `PDFMergeService` performs in-memory document recombination while preserving vector graphics, outlines, metadata, and form annotations.
- **Split & Burst**: `PDFSplitService` parses page trees and extracts sub-ranges into standalone multi-page or single-page PDF documents.
- **Adaptive Compression**: `PDFCompressService` calculates target size budgets and performs bitmap downsampling with targeted JPEG/TIFF compression factors.
- **On-Device Vision OCR**: `VisionOCRService` uses `VNRecognizeTextRequest` to extract machine-readable text and produce Markdown or searchable PDFs.

### 2. Media Studio Engine
- **Lossless Stream Processing**: `LosslessVideoTrimmer` utilizes `-ss` seek positioning and `-c copy` stream copying to perform sub-second keyframe-accurate cuts without CPU/GPU transcoding.
- **Audio Extraction & Stripping**: `AudioExtractorService` demuxes audio tracks to high-bitrate MP3, AAC, FLAC, and WAV, or generates silent video files with zero loss.
- **Video Geometry & Speed**: `VideoGeometrySpeedService` executes rotation (90, 180, 270 degrees) and variable speed modifications (0.25x to 4.0x) with pitch preservation.
- **Neural Subject Segmentation**: `NeuralSubjectSegmentationService` leverages `VNGenerateForegroundInstanceMaskRequest` on Apple Silicon Neural Engine to isolate foreground subjects with anti-aliased alpha transparency.
- **Watermarking & Privacy**: `WatermarkService` and `EXIFSanitizerService` handle batch branding and complete EXIF/GPS metadata elimination.

### 3. Archive & Compression Engine
- **Universal Unpacker**: `ArchiveService` supports ZIP, TAR, GZ, BZ2, XZ, 7Z, RAR, and ISO formats.
- **Encrypted Archives**: Strong AES-256 password protection and multi-part volume chunking.

### 4. Smart Automation & Ingestion
- **Watch Folder Monitoring**: `WatchFolderService` uses `DispatchSourceFileSystemObject` for non-blocking file system event monitoring.
- **Batch Token Renaming**: `TokenRenamer` provides template tokens (`{name}`, `{ext}`, `{date}`, `{counter:3}`) and regex transformations.

### 5. Universal Adaptive Canvas
- **SwiftUI Interface**: `UniversalCanvasView` dynamically inspects dropped items and presents tailored 1-click action drawers.

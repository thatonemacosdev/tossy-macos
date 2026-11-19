# Tossy 2.1.0 Stable Release Notes

> **Version**: 2.1.0 (Build 2026.11.19)  
> **Platform**: macOS 14.0+ (Sonoma, Sequoia)  
> **Architecture**: Apple Silicon & Universal Binary  
> **Distribution**: `dist/Tossy-2.1.0-macOS.zip` (SHA-256: `118a3a86fa300fe511b1cb22420aa91dde14bb8e0cd2476336916401eb11a34c`)

---

## Overview

**Tossy 2.1.0** delivers a major redesign focused on purity, clarity, and speed. Following strict anti-slop visual and architectural principles, Tossy 2.1 strips away cluttered sidebars and AI tropes in favor of a **Dropzone-First Homepage**, intelligent drag-and-drop auto-routing, an expanded suite of 11 handcrafted dark and light themes with natural names, a completely refreshed Menu Bar Quick-Toss interface, and a one-time community appreciation banner.

---

## Key Highlights and New Features

### 1. Dropzone-First Homepage (Studios Sidebar Removed)
- **Zero-Clutter Canvas**: The studios sidebar on the main homepage has been completely eliminated. When launching Tossy, you are greeted with a full-bleed, distraction-free dropzone canvas.
- **Intelligent Contextual Drop Routing**:
  - **PDF Documents**: Dropping any `.pdf` file automatically detects document workflows and launches **PDF Studio** with page merge, split, burst, compression, and OCR extraction.
  - **Code & Script Files**: Dropping source code (`.swift`, `.py`, `.js`, `.ts`, `.rs`, `.go`, `.rb`, `.cpp`, `.css`, `.sh`, `.json`, etc.) instantly opens **Code Card Studio** to render Carbon-style presentation cards.
  - **Images & Videos**: Dropping media files surfaces a contextual studio action bar within the DropZone, giving immediate one-click access to **Image Studio** (AI Background Removal, EXIF Sanitizer, Quality Inspector) or **Media Studio** (Lossless Cut/Trim, Audio Extraction, Playback Speed & Rotation), alongside instant conversion.

### 2. Complete Themes Redesign: Dark & Light Palettes
- **True Monochrome Modes**:
  - **Monochrome Black**: Pitch black canvas engineered for OLED and Retina displays with crisp white accents.
  - **Monochrome White**: Pure paper-white canvas with deep black contrast.
- **Natural, Human Theme Names**:
  - Removed cliché AI marketing buzzwords (e.g., "Hyper", "Neon", "Matrix", "Terminal").
  - Removed all decorative emojis from menus and pickers in adherence to clean macOS typography standards.
- **Categorized Theme Picker**:
  - **Dark Themes (7)**: Monochrome Black, Cobalt, Emerald, Amber, Violet, Titanium, Liquid Glass.
  - **Light Themes (4)**: Monochrome White, Rose (muted blush pink), Cream (warm parchment yellow), Sage (pale earthy green).
- **High-Contrast Accessibility & Dynamic Appearance**:
  - Full WCAG AAA contrast across all 11 themes.
  - Dynamic `preferredColorScheme` matching (`.dark` or `.light`) propagated across sheets, modals, and inspectors.

### 3. Redesigned Menu Bar Quick-Toss UI
- **Category Selector Pills**: Fast navigation across Image, Video, and Audio conversion categories with smooth sliding spring transitions.
- **Responsive Format Chip Grid**: Clean, high-contrast format badges tailored to each category.
- **Middle Truncation**: File labels now use middle truncation (`longfilename...part.ext`), guaranteeing file extensions are never cut off or awkwardly wrapped.
- **Window Lifecycle Fix**: The "Open App" button in Quick-Toss now reliably activates and reopens the main window even if it was previously closed or hidden.

### 4. Layout, Animation & Concentric Alignment Fixes
- **Concentric DropZone Ring Alignment**: Fixed a geometric offset during hover states, ensuring the center sync icon remains concentric with pulsing radar rings.
- **Label Wrapping & Clipping Safeguards**: Resolved layout regressions where status badges and format options could wrap vertically.
- **Fluid Micro-Interactions**: Tactile system haptics (`NSHapticFeedbackManager`) and audio feedback tuned for file drops, studio routing, and completion events.

### 5. Classic Tabs Mode Deadlock Fix
- **Deadlock Resolution**: Resolved a critical startup crash (`_dispatch_once_wait.cold.1` cycle deadlock / exit code 134) when toggling into Classic Three-Tabs mode.
- **Subprocess Decoupling**: Replaced synchronous `Process.waitUntilExit()` calls during SwiftUI view evaluation with static baseline codec capabilities (`libx264`, `libx265`, `libvpx`, `libopus`, `flac`, `prores`) and asynchronous background capability probing, preventing RunLoop pumping.

### 6. One-Time GitHub Star Community Prompt
- **Respectful & Unobtrusive**: A non-intrusive banner appears after the user successfully completes their first conversion.
- **Absolute Permanence Guarantee**: Whether the user clicks "Star on GitHub" or "No thanks", Tossy permanently records the decision in user preferences. The prompt will never be shown again.

---

## Test Suite & Verification

All 7 test pillars passed with 100% success:
- **Pillar 1 (PDF Studio)**: Merge, split, burst, Quartz compression, Apple Vision OCR: **PASSED**
- **Pillar 2 (Media Studio)**: Lossless trimming, audio extraction, overlays, speed controls: **PASSED**
- **Pillar 3 (Archive Studio)**: ZIP/TAR/GZ compression, AES-256 encryption, volume splitting: **PASSED**
- **Pillar 4 (Automation & CLI)**: Headless worker, URL scheme dispatch (`tossy://`), Quick Actions: **PASSED**
- **Pillar 5 (Regression & Bug Fixes)**: Audio-only WebM transcoding, subprocess hygiene: **PASSED**
- **Pillar 6 (V2 Polish)**: Token renaming, dynamic mode detection, drag-away chips, Code Card Studio routing: **PASSED**
- **Pillar 7 (V2.1 Redesign & Star Prompt)**: 11 split light/dark themes, auto-routing rules, Quick-Toss redesign, window lifecycle, classic tab stability, one-time GitHub star prompt lifecycle: **PASSED**

---

## Installation & First Launch

1. Download [`Tossy-2.1.0-macOS.zip`](https://github.com/thatonemacosdev/tossy-macos/releases/tag/v2.1.0).
2. Unzip and move `Tossy.app` to your `/Applications` directory.
3. **First-time open**:
   - Right-click (or Control-click) `Tossy.app` and choose **Open**, then confirm **Open** in the macOS dialog.
   - Or run: `xattr -cr /Applications/Tossy.app`.

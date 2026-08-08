This directory bundles an FFmpeg build (ffmpeg + ffprobe, arm64) built by Homebrew's
`ffmpeg` formula, configured with `--enable-gpl` and including libx264/libx265.

**This build is licensed under the GPL** (not LGPL), because it links libx264/libx265.
That's fine for personal use or open-source distribution of this project (the source
of both this app and FFmpeg itself is available), but if you plan to distribute
EasyConvert as closed-source or commercially, you have two options:

1. Rebuild FFmpeg from source with `--disable-gpl` (drops libx264/libx265 - fine,
   since EasyConvert already does H.264/HEVC encoding natively via VideoToolbox/
   AVFoundation without FFmpeg) and swap the binaries in this folder.
2. Comply with the GPL for this component (make source available, etc).

The dylibs in `libs/` were relinked with `dylibbundler` so `ffmpeg`/`ffprobe` here
run standalone, with no dependency on Homebrew being installed.

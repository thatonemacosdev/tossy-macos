import UniformTypeIdentifiers

enum ImageBackend {
    case imageIO
    case ffmpeg(codec: String)
    case webpTool
    case jxlTool
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case png, jpeg, heic, tiff, bmp, gif, jpeg2000, avif, ico, tga
    case webp, psd, icns, dds, exr, hdr, pnm, qoi, farbfeld, jxl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        case .bmp: return "BMP"
        case .gif: return "GIF"
        case .jpeg2000: return "JPEG 2000"
        case .avif: return "AVIF"
        case .ico: return "ICO"
        case .tga: return "TGA"
        case .webp: return "WebP"
        case .psd: return "PSD (Photoshop)"
        case .icns: return "ICNS (macOS icon)"
        case .dds: return "DDS"
        case .exr: return "OpenEXR"
        case .hdr: return "Radiance HDR"
        case .pnm: return "PNM (PPM)"
        case .qoi: return "QOI"
        case .farbfeld: return "Farbfeld"
        case .jxl: return "JPEG XL"
        }
    }

    var backend: ImageBackend {
        switch self {
        case .png, .jpeg, .heic, .tiff, .bmp, .gif, .jpeg2000, .avif, .ico, .tga, .psd, .icns, .dds, .exr:
            return .imageIO
        case .webp:
            return .webpTool
        case .hdr: return .ffmpeg(codec: "hdr")
        case .pnm: return .ffmpeg(codec: "ppm")
        case .qoi: return .ffmpeg(codec: "qoi")
        case .farbfeld: return .ffmpeg(codec: "farbfeld")
        case .jxl: return .jxlTool
        }
    }

    /// Only meaningful for `.imageIO`-backed formats.
    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        case .jpeg2000: return UTType("public.jpeg-2000")!
        case .avif: return UTType("public.avif")!
        case .ico: return UTType("com.microsoft.ico")!
        case .tga: return UTType("com.truevision.tga-image")!
        case .psd: return UTType("com.adobe.photoshop-image")!
        case .icns: return UTType("com.apple.icns")!
        case .dds: return UTType("com.microsoft.dds")!
        case .exr: return UTType("com.ilm.openexr-image")!
        default: return .data
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .bmp: return "bmp"
        case .gif: return "gif"
        case .jpeg2000: return "jp2"
        case .avif: return "avif"
        case .ico: return "ico"
        case .tga: return "tga"
        case .webp: return "webp"
        case .psd: return "psd"
        case .icns: return "icns"
        case .dds: return "dds"
        case .exr: return "exr"
        case .hdr: return "hdr"
        case .pnm: return "ppm"
        case .qoi: return "qoi"
        case .farbfeld: return "ff"
        case .jxl: return "jxl"
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .jpeg, .heic, .jpeg2000, .avif, .webp, .jxl: return true
        default: return false
        }
    }

    /// Whether this format can actually be produced given what's bundled/installed right now.
    /// (Some formats, like JXL/Farbfeld, need an ffmpeg build with support compiled in.)
    var isAvailable: Bool {
        // ImageIO's DDS writer silently produces an empty (0-byte) file on this platform
        // regardless of return status  -  confirmed by direct testing, not a hypothetical.
        if self == .dds { return false }

        switch backend {
        case .imageIO:
            return true
        case .webpTool:
            return WebPLocator.cwebpPath != nil
        case .jxlTool:
            return JXLLocator.cjxlPath != nil
        case .ffmpeg(let codec):
            return FFmpegLocator.isAvailable && FFmpegCapabilities.shared.canEncode(codec)
        }
    }

    var unavailabilityReason: String? {
        guard !isAvailable else { return nil }
        if self == .dds {
            return "macOS's image writer produces empty DDS files on this system  -  there's no working encoder available for this format right now."
        }
        switch backend {
        case .webpTool:
            return "The bundled WebP encoder (cwebp) wasn't found."
        case .jxlTool:
            return "The bundled JPEG XL encoder (cjxl) wasn't found."
        case .ffmpeg:
            return "This build of ffmpeg wasn't compiled with \(displayName) support."
        case .imageIO:
            return nil
        }
    }

    /// Everything ImageIO can decode (camera RAW, WebP, ICO, etc.) plus vector/document
    /// sources we rasterize ourselves (SVG, PDF, and PDF-compatible EPS/AI files).
    static let readableContentTypes: [UTType] = [
        .image, .svg, .pdf,
        UTType(filenameExtension: "eps"),
        UTType(filenameExtension: "ai")
    ].compactMap { $0 }

    static let readableExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif",
        "jp2", "j2k", "avif", "ico", "tga", "webp", "psd", "icns", "dds",
        "exr", "hdr", "ppm", "pgm", "pbm", "pnm", "qoi", "ff", "jxl",
        "svg", "pdf", "eps", "ai", "dng", "cr2", "cr3", "nef", "arw", "rw2"
    ]

    /// Maps a source file's extension back to one of our writable formats  -  used by
    /// "keep original format" (recompress in place without converting).
    static func matching(sourceURL: URL) -> ImageFormat? {
        let ext = sourceURL.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "tif", "tiff": return .tiff
        case "bmp": return .bmp
        case "gif": return .gif
        case "jp2", "j2k": return .jpeg2000
        case "avif": return .avif
        case "ico": return .ico
        case "tga": return .tga
        case "webp": return .webp
        case "psd": return .psd
        case "icns": return .icns
        case "dds": return .dds
        case "exr": return .exr
        case "hdr": return .hdr
        case "ppm", "pgm", "pbm", "pnm": return .pnm
        case "qoi": return .qoi
        case "ff": return .farbfeld
        case "jxl": return .jxl
        default: return nil
        }
    }
}

import CoreImage
import UniformTypeIdentifiers

/// Detects and decodes camera RAW files (CR2, CR3, NEF, ARW, DNG, ORF, RW2, RAF, PEF, and more)
/// using macOS's built-in RAW pipeline (`CIRAWFilter`)  -  the same decoders Preview and Photos
/// use, covering essentially every mainstream camera without needing LibRaw.
enum RawImageDecoder {
    static func isRawImage(at url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: UTType("public.camera-raw-image")!)
    }

    /// Returns a fully demosaiced, color-managed `CIImage` using the camera's default RAW
    /// processing (white balance, noise reduction, etc.), or `nil` if this isn't a RAW file
    /// or the file is corrupt/unsupported.
    static func decode(url: URL) -> CIImage? {
        guard isRawImage(at: url), let filter = CIRAWFilter(imageURL: url) else { return nil }
        return filter.outputImage
    }
}

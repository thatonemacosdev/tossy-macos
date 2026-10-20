import Foundation
import SwiftUI

struct GitHubReleaseItem: Identifiable, Sendable {
    let id: Int
    let tagName: String
    let name: String
    let publishedAt: String
    let formattedDate: String
    let htmlURL: URL
    let body: String
    let highlights: [String]
    
    var versionString: String {
        tagName.hasPrefix("v") || tagName.hasPrefix("V") ? tagName : "v\(tagName)"
    }
}

@Observable
final class GitHubChangelogService: @unchecked Sendable {
    static let shared = GitHubChangelogService()
    
    var releases: [GitHubReleaseItem] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var visibleCount: Int = 3
    
    private init() {
        loadFallbackReleases()
        Task {
            await fetchReleases()
        }
    }
    
    func loadMore() {
        visibleCount = min(visibleCount + 3, max(releases.count, 3))
    }
    
    var canLoadMore: Bool {
        visibleCount < releases.count
    }
    
    var visibleReleases: [GitHubReleaseItem] {
        Array(releases.prefix(visibleCount))
    }
    
    func fetchReleases() async {
        if isLoading { return }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let apiURL = URL(string: "https://api.github.com/repos/thatonemacosdev/tossy-macos/releases?per_page=100")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Tossy-macOS-Changelog", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.loadFallbackReleases()
                    self.isLoading = false
                }
                return
            }
            
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                await MainActor.run {
                    self.loadFallbackReleases()
                    self.isLoading = false
                }
                return
            }
            
            var parsed: [GitHubReleaseItem] = []
            
            for item in jsonArray {
                guard let id = item["id"] as? Int,
                      let tagName = item["tag_name"] as? String,
                      let rawName = item["name"] as? String,
                      let body = item["body"] as? String,
                      let htmlUrlStr = item["html_url"] as? String,
                      let htmlURL = URL(string: htmlUrlStr) else { continue }
                
                let pubDateStr = item["published_at"] as? String ?? ""
                let formattedDate = Self.formatDate(pubDateStr)
                let name = rawName.isEmpty ? tagName : rawName
                let highlights = Self.extractHighlights(from: body, fallbackName: name)
                
                let releaseItem = GitHubReleaseItem(
                    id: id,
                    tagName: tagName,
                    name: name,
                    publishedAt: pubDateStr,
                    formattedDate: formattedDate,
                    htmlURL: htmlURL,
                    body: body,
                    highlights: highlights
                )
                parsed.append(releaseItem)
            }
            
            let finalReleases = parsed
            await MainActor.run {
                if !finalReleases.isEmpty {
                    self.releases = finalReleases
                } else {
                    self.loadFallbackReleases()
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadFallbackReleases()
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Markdown & Highlights Extractor
    
    static func extractHighlights(from body: String, fallbackName: String) -> [String] {
        var points: [String] = []
        let lines = body.components(separatedBy: .newlines)
        
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip noisy headers, download links, asset blocks, and metadata
            if trimmed.isEmpty ||
               trimmed.hasPrefix("#") ||
               trimmed.hasPrefix("---") ||
               trimmed.hasPrefix("***") ||
               trimmed.hasPrefix("**Release Tag") ||
               trimmed.hasPrefix("**Release Target") ||
               trimmed.hasPrefix("**License") ||
               trimmed.hasPrefix("**Download") ||
               trimmed.hasPrefix("Download") ||
               trimmed.hasPrefix("[`Tossy") ||
               trimmed.contains("github.com/thatonemacosdev/tossy-macos/releases/download") {
                continue
            }
            
            // Extract bullet points or clean text lines
            var cleanPoint: String? = nil
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                cleanPoint = String(trimmed.dropFirst(2))
            } else if trimmed.count > 3 && trimmed.first?.isNumber == true && trimmed.contains(". ") {
                if let dotIdx = trimmed.firstIndex(of: ".") {
                    let afterDot = trimmed[trimmed.index(after: dotIdx)...].trimmingCharacters(in: .whitespaces)
                    cleanPoint = afterDot
                }
            } else if !trimmed.hasPrefix("<") && !trimmed.hasPrefix("[") && trimmed.count > 15 {
                cleanPoint = trimmed
            }
            
            if var point = cleanPoint {
                // Strip markdown bold/code markers and replace em/en dashes
                point = point
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .replacingOccurrences(of: "\u{2014}", with: " - ")
                    .replacingOccurrences(of: "\u{2013}", with: " - ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !point.isEmpty && point.count > 8 && !points.contains(point) {
                    points.append(point)
                    if points.count >= 6 {
                        break
                    }
                }
            }
        }
        
        if points.isEmpty {
            points.append("\(fallbackName) performance optimizations, native stability updates, and feature enhancements.")
        }
        
        return points
    }
    
    static func formatDate(_ isoString: String) -> String {
        guard !isoString.isEmpty else { return "August 2026" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            let simpleFormatter = ISO8601DateFormatter()
            date = simpleFormatter.date(from: isoString)
        }
        
        guard let validDate = date else {
            return String(isoString.prefix(10))
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: validDate)
    }
    
    // MARK: - Offline Fallback Cache
    
    private func loadFallbackReleases() {
        let fallbackTags: [(tag: String, date: String, items: [String])] = [
            ("v2.0.0", "October 2026", [
                "Official 2.0.0 Stable Release: robust, battle-tested media powerhouse.",
                "New Launch on Startup option in Settings and macOS Menu Bar.",
                "Full support for audio-only WebM files (Opus & Vorbis) with automatic format routing and FFmpeg fallback.",
                "Universal File Canvas with multi-selection and batch token renaming.",
                "Complete PDF Studio: merge, split ranges, burst, compress, and Apple Vision OCR.",
                "Lossless Video Trimmer, audio extraction, watermarking, and speed controls.",
                "Menu Bar Quick-Toss drag-to-open and drop handling.",
                "Carbon-style Code Card PNG exporter with syntax highlighting.",
                "Archive Suite with AES-256 password encryption and volume splitting.",
                "Smart kernel Watch Folders engine for automated background directory monitoring.",
                "Side-by-Side Quality Inspector with synchronized real-time video playback."
            ]),
            ("v2.0.0-beta", "October 2026", [
                "Universal File Canvas with multi-selection and batch token renaming.",
                "Complete PDF Studio: merge, split ranges, burst, compress, and Apple Vision OCR.",
                "Lossless Video Trimmer, audio extraction, watermarking, and speed controls.",
                "Menu Bar Quick-Toss drag-to-open and drop handling."
            ]),
            ("v1.7.1", "August 2026", [
                "Zero-overwrite policy: automatic numeric suffixes prevent file collisions.",
                "Unified Finder Quick Action opening dedicated Mini Tossy modal.",
                "Sanitized UI and refined Apple SF Symbols across all workspaces."
            ]),
            ("v1.7.0", "August 2026", [
                "Menu Bar Quick-Toss status bar dropzone.",
                "Native macOS completion chimes and system notifications.",
                "ZIP-first automated release deployment."
            ]),
            ("v1.6.2", "August 2026", [
                "Lossless image conversion engine enhancements.",
                "Refined WebP sharp YUV encoding and SNS filters.",
                "Batch progress bar optimizations."
            ]),
            ("v1.6.1", "August 2026", [
                "Hot folder watcher bug fixes and permission handling.",
                "Automated updater DMG and ZIP verification.",
                "Reduced peak memory consumption during high-resolution batch tasks."
            ]),
            ("v1.6.0", "August 2026", [
                "Integrated JPEG XL suite (cjxl, djxl) bundled natively.",
                "Lossless video format conversions and WebM encoding.",
                "Refined macOS dark titanium visual design system."
            ]),
            ("v1.5.3", "August 2026", [
                "Multi-threading engine speedups for 4K video transcoding.",
                "EXIF and GPS metadata stripping safeguards.",
                "Added custom output directory naming templates."
            ]),
            ("v1.5.2", "August 2026", [
                "High DPI PDF page extraction fixes.",
                "Extended drag-and-drop MIME format support.",
                "Enhanced audio bitrate and channel rate selectors."
            ]),
            ("v1.5.1", "August 2026", [
                "UI responsiveness improvements on Intel and Apple Silicon Macs.",
                "Corrected file conflict resolution dialogs.",
                "Added keyboard shortcuts for quick conversion execution."
            ]),
            ("v1.5.0", "August 2026", [
                "Introduced Media Studio lossless audio extractor.",
                "Added video geometry rotation and speed multiplier controls.",
                "Optimized WebP animated GIF conversion speed."
            ]),
            ("v1.4.0", "August 2026", [
                "Added token-based batch file renamer with live preview.",
                "Initial implementation of background watch folders.",
                "Performance fixes for large multi-gigabyte media queues."
            ]),
            ("v1.3.3", "August 2026", [
                "Security and permissions sandboxing updates.",
                "Fixed temporary directory cleanup on abnormal process termination.",
                "Added FLAC, ALAC, and OGG audio transcoding."
            ]),
            ("v1.3.2", "August 2026", [
                "Introduced side-by-side visual comparison split slider.",
                "Improved error diagnostics for corrupted image headers.",
                "Minor design tweaks to Settings tabs."
            ]),
            ("v1.3.1", "August 2026", [
                "Added JPEG XL Butteraugli distance tuning.",
                "Fixed drag-and-drop sorting in batch list.",
                "Updated ffmpeg and cwebp vendored binaries."
            ]),
            ("v1.3.0", "August 2026", [
                "Introduced PDF compression and merger tools.",
                "Added support for HEIC to PNG/JPEG conversion.",
                "Streamlined application menu bar commands."
            ]),
            ("v1.2.1", "August 2026", [
                "Fixed memory leak during animated GIF generation.",
                "Added system audio chime toggles in preferences.",
                "Enhanced status bar icon crispness on Retina displays."
            ]),
            ("v1.2.0", "August 2026", [
                "Added video transcoding to MP4 H.264, HEVC, and MKV.",
                "Added video quality CRF and preset bitrate controls.",
                "Added hardware acceleration via VideoToolbox."
            ]),
            ("v1.0.1", "August 2026", [
                "Initial bug fix update resolving WebP alpha channel transparency issues.",
                "Added drag-and-drop badge counts."
            ]),
            ("v1.0.0", "August 2026", [
                "Initial public release of Tossy for macOS.",
                "High performance image conversion for PNG, JPEG, WebP, TIFF, and GIF."
            ])
        ]
        
        self.releases = fallbackTags.enumerated().map { idx, tagData in
            GitHubReleaseItem(
                id: 1000 + idx,
                tagName: tagData.tag,
                name: "Tossy \(tagData.tag)",
                publishedAt: tagData.date,
                formattedDate: tagData.date,
                htmlURL: URL(string: "https://github.com/thatonemacosdev/tossy-macos/releases/tag/\(tagData.tag)")!,
                body: tagData.items.joined(separator: "\n"),
                highlights: tagData.items
            )
        }
    }
}

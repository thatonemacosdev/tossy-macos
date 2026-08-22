import SwiftUI

struct EXIFSanitizerModalView: View {
    let sourceURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIndex: Int = 0
    @State private var metadataReport: ImageMetadataReport?
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String?
    @State private var sanitizedOutputs: [URL] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Metadata & EXIF Privacy Sanitizer")
                        .font(.headline)
                    Text("\(sourceURLs.count) image(s) loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let report = metadataReport {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Inspected Metadata Tags:")
                                .font(.subheadline.bold())
                            
                            HStack {
                                Label(report.hasGPS ? "GPS Location Present" : "Zero GPS Tags", systemImage: report.hasGPS ? "location.fill" : "location.slash")
                                    .foregroundStyle(report.hasGPS ? .red : .green)
                                    .font(.subheadline.bold())
                                
                                Spacer()
                                
                                if let lat = report.gpsLatitude, let lon = report.gpsLongitude {
                                    Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                            
                            if let make = report.cameraMake, let model = report.cameraModel {
                                metadataRow(label: "Camera Hardware", value: "\(make) \(model)")
                            }
                            if let lens = report.lensModel {
                                metadataRow(label: "Lens Profile", value: lens)
                            }
                            if let date = report.dateTimeOriginal {
                                metadataRow(label: "Timestamp Original", value: date)
                            }
                            if let software = report.software {
                                metadataRow(label: "Editing Software", value: software)
                            }
                            
                            metadataRow(label: "Total Properties Found", value: "\(report.rawPropertyCount) EXIF/TIFF entries")
                        }
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Inspecting image metadata...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                    }
                    
                    if !sanitizedOutputs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sanitized Output Files:")
                                .font(.caption.bold())
                            ForEach(sanitizedOutputs, id: \.self) { url in
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(.green)
                                    Text(url.lastPathComponent)
                                        .font(.caption.monospaced())
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                if isProcessing {
                    ProgressView().controlSize(.small)
                    Text("Sanitizing metadata...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !sanitizedOutputs.isEmpty {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(sanitizedOutputs)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Sanitize All Metadata") {
                    sanitizeFiles()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || sourceURLs.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 440)
        .onAppear {
            inspectFirst()
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    private func inspectFirst() {
        guard let first = sourceURLs.first else { return }
        Task {
            if let report = try? await EXIFSanitizerService.shared.readMetadata(imageURL: first) {
                await MainActor.run {
                    self.metadataReport = report
                }
            }
        }
    }
    
    private func sanitizeFiles() {
        isProcessing = true
        statusMessage = "Stripping all EXIF, GPS & timestamp tags..."
        
        Task {
            var outputs: [URL] = []
            for url in sourceURLs {
                let folder = url.deletingLastPathComponent()
                let base = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                let desired = folder.appendingPathComponent("\(base)_sanitized.\(ext)")
                if let out = try? await EXIFSanitizerService.shared.stripMetadata(sourceURL: url, destinationURL: desired) {
                    outputs.append(out)
                }
            }
            
            await MainActor.run {
                self.sanitizedOutputs = outputs
                self.statusMessage = "Sanitized \(outputs.count) image(s) with 100% metadata stripped."
                self.isProcessing = false
            }
        }
    }
}

import SwiftUI

enum ArchiveFormatOption: String, CaseIterable, Identifiable {
    case zip = "ZIP (.zip)"
    case targz = "TAR GZ (.tar.gz)"
    case tar = "TAR (.tar)"
    
    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .zip: return "zip"
        case .targz: return "tar.gz"
        case .tar: return "tar"
        }
    }
}

enum ArchiveCompressionLevel: String, CaseIterable, Identifiable {
    case fast = "Fast (Low CPU)"
    case normal = "Balanced (Standard)"
    case maximum = "Maximum (Smallest Size)"
    
    var id: String { rawValue }
}

struct ArchiveOptionsModalView: View {
    let sourceURLs: [URL]
    var onComplete: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    @State private var format: ArchiveFormatOption = .zip
    @State private var archiveName: String = "Archive"
    @State private var compressionLevel: ArchiveCompressionLevel = .normal
    @State private var isPasswordProtected: Bool = false
    @State private var passwordText: String = ""
    @State private var splitIntoVolumes: Bool = false
    @State private var volumeChunkSizeMB: Int = 100
    
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String?
    @State private var outputURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archive Suite Options")
                        .font(.headline)
                    Text("\(sourceURLs.count) file(s) to pack")
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
            
            Form {
                Section("Archive Format & Output") {
                    Picker("Format", selection: $format) {
                        ForEach(ArchiveFormatOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Archive Name", text: $archiveName)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Compression", selection: $compressionLevel) {
                        ForEach(ArchiveCompressionLevel.allCases) { lvl in
                            Text(lvl.rawValue).tag(lvl)
                        }
                    }
                }
                
                Section("Security & Encryption") {
                    Toggle("Enable AES-256 Password Encryption", isOn: $isPasswordProtected)
                        .toggleStyle(.checkbox)
                        .disabled(format != .zip)
                    
                    if isPasswordProtected {
                        SecureField("Enter Archive Password", text: $passwordText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section("Multi-Part Volumes") {
                    Toggle("Split into Multi-Part Volume Chunks", isOn: $splitIntoVolumes)
                        .toggleStyle(.checkbox)
                    
                    if splitIntoVolumes {
                        Stepper("Volume Chunk Size: \(volumeChunkSizeMB) MB", value: $volumeChunkSizeMB, in: 5...2000, step: 25)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                if isProcessing {
                    ProgressView().controlSize(.small)
                    Text("Compressing archive...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let outputURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Create Archive") {
                    executeArchiveCreation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || sourceURLs.isEmpty || (isPasswordProtected && passwordText.isEmpty))
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 520, height: 480)
        .onAppear {
            if let first = sourceURLs.first {
                if sourceURLs.count == 1 {
                    archiveName = first.deletingPathExtension().lastPathComponent
                } else {
                    archiveName = "\(first.deletingPathExtension().lastPathComponent)_bundle"
                }
            }
        }
    }
    
    private func executeArchiveCreation() {
        guard let first = sourceURLs.first else { return }
        isProcessing = true
        statusMessage = "Packing archive..."
        
        let destinationFolder = first.deletingLastPathComponent()
        let cleanName = archiveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Archive" : archiveName
        let ext = format.fileExtension
        let desired = destinationFolder.appendingPathComponent("\(cleanName).\(ext)")
        let pass = isPasswordProtected ? passwordText : nil
        
        Task {
            do {
                let res = try await ArchiveService.shared.createArchive(
                    sourceURLs: sourceURLs,
                    format: ext,
                    password: pass,
                    destinationURL: desired
                )
                
                if splitIntoVolumes {
                    let chunkBytes = Int64(volumeChunkSizeMB) * 1024 * 1024
                    let volumeFolder = destinationFolder.appendingPathComponent("\(cleanName)_volumes")
                    _ = try await ArchiveService.shared.splitIntoVolumes(
                        archiveURL: res,
                        chunkSizeBytes: chunkBytes,
                        destinationFolder: volumeFolder
                    )
                }
                
                await MainActor.run {
                    self.outputURL = res
                    self.statusMessage = "Created \(res.lastPathComponent) successfully."
                    self.isProcessing = false
                    self.onComplete?(res)
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}

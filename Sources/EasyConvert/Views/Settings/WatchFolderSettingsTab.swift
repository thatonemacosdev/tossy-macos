import SwiftUI
import AppKit

struct WatchFolderItem: Identifiable, Codable {
    var id: UUID = UUID()
    var folderPath: String
    var preset: String
    var isEnabled: Bool = true
}

struct WatchFolderSettingsTab: View {
    @State private var folders: [WatchFolderItem] = []
    @State private var selectedFolder: WatchFolderItem?
    
    let presets = [
        "Auto-convert Images to WebP",
        "Auto-convert Images to PNG",
        "Auto-convert Videos to MP4",
        "Auto-compress PDFs (150 DPI)",
        "Auto-strip EXIF Metadata",
        "Auto-extract MP3 Audio"
    ]
    
    var body: some View {
        Form {
            Section("Smart Folder Ingestion (Hot Folders)") {
                Text("Tossy monitors designated local folders in real-time and automatically executes conversions whenever files are dropped into them.")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                
                if folders.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 32))
                                .foregroundStyle(TossyColor.textTertiary)
                            Text("No watch folders configured yet.")
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                            Button("Add Folder…") {
                                addFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach($folders) { $item in
                            HStack {
                                Toggle("", isOn: $item.isEnabled)
                                    .labelsHidden()
                                    .onChange(of: item.isEnabled) { _, newValue in
                                        syncWatchers()
                                    }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(fileURLWithPath: item.folderPath).lastPathComponent)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(item.folderPath)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(TossyColor.textTertiary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Picker("", selection: $item.preset) {
                                    ForEach(presets, id: \.self) { p in
                                        Text(p).tag(p)
                                    }
                                }
                                .frame(width: 180)
                                .onChange(of: item.preset) { _, _ in
                                    syncWatchers()
                                }
                                
                                Button {
                                    removeFolder(id: item.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minHeight: 160)
                    
                    HStack {
                        Spacer()
                        Button("Add Folder…") {
                            addFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            Section("Monitoring Engine Status") {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                    Text("Apple DispatchSource Kernel Watcher")
                        .font(.caption.bold())
                    Spacer()
                    Text("Zero CPU Idle Consumption")
                        .font(.caption2)
                        .foregroundStyle(TossyColor.textTertiary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSavedFolders()
        }
    }
    
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Monitored Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            let item = WatchFolderItem(folderPath: url.path, preset: presets[0], isEnabled: true)
            folders.append(item)
            saveFolders()
            syncWatchers()
        }
    }
    
    private func removeFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        WatchFolderService.shared.stopMonitoring(ruleId: id)
        saveFolders()
    }
    
    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "tossy_watch_folders")
        }
    }
    
    private func loadSavedFolders() {
        if let data = UserDefaults.standard.data(forKey: "tossy_watch_folders"),
           let decoded = try? JSONDecoder().decode([WatchFolderItem].self, from: data) {
            self.folders = decoded
            syncWatchers()
        }
    }
    
    private func syncWatchers() {
        WatchFolderService.shared.stopAll()
        for item in folders where item.isEnabled {
            let url = URL(fileURLWithPath: item.folderPath)
            let rule = WatchFolderRule(id: item.id, folderURL: url, targetFormat: item.preset, isEnabled: true)
            WatchFolderService.shared.startMonitoring(rule: rule) { fileURL, activeRule in
                // Handle file ingestion
                print("WatchFolder ingested: \(fileURL.lastPathComponent) for preset: \(activeRule.targetFormat)")
            }
        }
    }
}

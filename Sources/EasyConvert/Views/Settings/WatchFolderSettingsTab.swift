import SwiftUI
import AppKit

struct WatchFolderSettingsTab: View {
    @State private var folders: [WatchFolderRule] = []

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
                                    .onChange(of: item.isEnabled) { _, _ in
                                        saveAndSync()
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
                                    saveAndSync()
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
                    Text("Active & Ready")
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
            let item = WatchFolderRule(folderPath: url.path, preset: presets[0], isEnabled: true)
            folders.append(item)
            saveAndSync()
        }
    }

    private func removeFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        saveAndSync()
    }

    private func saveAndSync() {
        WatchFolderService.shared.syncRules(folders)
    }

    private func loadSavedFolders() {
        folders = WatchFolderService.shared.savedRules()
    }
}

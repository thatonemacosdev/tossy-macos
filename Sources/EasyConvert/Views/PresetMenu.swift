import SwiftUI

enum PresetCategory {
    case image(onApply: (ImagePreset) -> Void, onSave: (String) -> Void)
    case video(onApply: (VideoPreset) -> Void, onSave: (String) -> Void)
    case audio(onApply: (AudioPreset) -> Void, onSave: (String) -> Void)
}

struct PresetMenu: View {
    @Bindable private var store = PresetStore.shared
    let category: PresetCategory

    @State private var isShowingSavePopover = false
    @State private var newPresetName = ""

    var body: some View {
        Menu {
            presetList

            Divider()

            Button {
                newPresetName = ""
                isShowingSavePopover = true
            } label: {
                Label("Save current settings as preset…", systemImage: "plus.circle")
            }
        } label: {
            Label("Presets", systemImage: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $isShowingSavePopover) {
            VStack(spacing: 12) {
                Text("Save Preset")
                    .font(.headline)
                TextField("Preset name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                HStack {
                    Button("Cancel") {
                        isShowingSavePopover = false
                    }
                    Button("Save") {
                        let name = newPresetName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty {
                            saveCurrent(name: name)
                        }
                        isShowingSavePopover = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var presetList: some View {
        switch category {
        case .image(let onApply, _):
            if store.imagePresets.isEmpty {
                Text("No saved image presets").foregroundStyle(.secondary)
            } else {
                ForEach(store.imagePresets) { preset in
                    Button(preset.name) {
                        onApply(preset)
                    }
                }
            }
        case .video(let onApply, _):
            if store.videoPresets.isEmpty {
                Text("No saved video presets").foregroundStyle(.secondary)
            } else {
                ForEach(store.videoPresets) { preset in
                    Button(preset.name) {
                        onApply(preset)
                    }
                }
            }
        case .audio(let onApply, _):
            if store.audioPresets.isEmpty {
                Text("No saved audio presets").foregroundStyle(.secondary)
            } else {
                ForEach(store.audioPresets) { preset in
                    Button(preset.name) {
                        onApply(preset)
                    }
                }
            }
        }
    }

    private func saveCurrent(name: String) {
        switch category {
        case .image(_, let onSave): onSave(name)
        case .video(_, let onSave): onSave(name)
        case .audio(_, let onSave): onSave(name)
        }
    }
}

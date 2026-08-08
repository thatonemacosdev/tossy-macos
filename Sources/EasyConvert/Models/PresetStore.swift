import Foundation

@Observable
final class PresetStore {
    static let shared = PresetStore()

    var imagePresets: [ImagePreset] = [] {
        didSet { if !isLoading { saveImagePresets() } }
    }
    var videoPresets: [VideoPreset] = [] {
        didSet { if !isLoading { saveVideoPresets() } }
    }
    var audioPresets: [AudioPreset] = [] {
        didSet { if !isLoading { saveAudioPresets() } }
    }

    private let imageKey = "EasyConvert.imagePresets"
    private let videoKey = "EasyConvert.videoPresets"
    private let audioKey = "EasyConvert.audioPresets"
    private var isLoading = false

    init() {
        isLoading = true
        loadImagePresets()
        loadVideoPresets()
        loadAudioPresets()
        isLoading = false
    }

    private func loadImagePresets() {
        guard let data = UserDefaults.standard.data(forKey: imageKey),
              let decoded = try? JSONDecoder().decode([ImagePreset].self, from: data) else { return }
        imagePresets = decoded
    }

    private func saveImagePresets() {
        if let encoded = try? JSONEncoder().encode(imagePresets) {
            UserDefaults.standard.set(encoded, forKey: imageKey)
        }
    }

    private func loadVideoPresets() {
        guard let data = UserDefaults.standard.data(forKey: videoKey),
              let decoded = try? JSONDecoder().decode([VideoPreset].self, from: data) else { return }
        videoPresets = decoded
    }

    private func saveVideoPresets() {
        if let encoded = try? JSONEncoder().encode(videoPresets) {
            UserDefaults.standard.set(encoded, forKey: videoKey)
        }
    }

    private func loadAudioPresets() {
        guard let data = UserDefaults.standard.data(forKey: audioKey),
              let decoded = try? JSONDecoder().decode([AudioPreset].self, from: data) else { return }
        audioPresets = decoded
    }

    private func saveAudioPresets() {
        if let encoded = try? JSONEncoder().encode(audioPresets) {
            UserDefaults.standard.set(encoded, forKey: audioKey)
        }
    }
}

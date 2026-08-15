import SwiftUI

@main
struct TossyApp: App {
    var body: some Scene {
        WindowGroup("Tossy") {
            RootView()
                .frame(minWidth: 640, minHeight: 460)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 720, height: 540)
        
        Settings {
            SettingsView()
        }
    }
}

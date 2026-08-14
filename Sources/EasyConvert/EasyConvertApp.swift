import SwiftUI

@main
struct TossyApp: App {
    var body: some Scene {
        WindowGroup("Tossy") {
            RootView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 640, height: 480)
        
        Settings {
            SettingsView()
        }
    }
}

import SwiftUI

@main
struct TossyApp: App {
    var body: some Scene {
        WindowGroup("Tossy") {
            RootView()
                .frame(minWidth: 640, minHeight: 460)
                .onAppear {
                    MenuBarManager.shared.setupIfNeeded()
                    if AppSettings.shared.automaticallyCheckForUpdates {
                        UpdateManager.shared.checkForUpdates(isUserInitiated: false)
                    }
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 720, height: 540)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                }
                Divider()
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

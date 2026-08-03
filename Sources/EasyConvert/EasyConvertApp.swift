import SwiftUI

@main
struct EasyConvertApp: App {
    var body: some Scene {
        WindowGroup("EasyConvert") {
            RootView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 640, height: 480)
    }
}

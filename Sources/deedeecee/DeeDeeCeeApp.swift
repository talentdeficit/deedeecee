import SwiftUI

@main
struct DeeDeeCeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MonitorMenuView()
        } label: {
            Image(systemName: "display.2")
        }
    }
}

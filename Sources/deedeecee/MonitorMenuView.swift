import SwiftUI

struct MonitorMenuView: View {
    @State private var service = MonitorService()

    var body: some View {
        Group {
            Section("External Monitors") {
                if service.monitors.isEmpty {
                    Text("none!")
                        .foregroundStyle(.secondary)
                }
                ForEach(service.monitors) { monitor in
                    Menu(monitor.name) {
                        ForEach(monitor.availableInputs) { entry in
                            Button(entry.label) {
                                service.setInput(entry.input, for: monitor.id)
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Settings…") {
                NSWorkspace.shared.open(AppConfig.configURL)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

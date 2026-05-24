import AppKit
import Foundation
import Observation

struct MonitorState: Identifiable {
    let display: ExternalDisplay
    let availableInputs: [InputEntry]
    let inputMode: InputMode
    var id: String { display.id }
    var name: String { display.name }
}

@Observable
@MainActor
final class MonitorService {
    var monitors: [MonitorState] = []
    private var config = AppConfig.load()
    private var configFileSource: DispatchSourceFileSystemObject?

    init() {
        ddcVerbose = config.diagnostics
        ddcDiagnose()
        refresh()
        startConfigWatcher()
        Task { @MainActor [weak self] in
            for _ in 0..<5 {
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.monitors.isEmpty else { break }
                self.refresh()
            }
        }
        Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.refresh()
            }
        }
    }

    private func startConfigWatcher() {
        let path = AppConfig.configURL.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.config = AppConfig.load()
                ddcVerbose = self.config.diagnostics
                self.refresh()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        configFileSource = source
    }

    func refresh() {
        let cfg = config
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                MonitorService.discover(config: cfg)
            }.value
            monitors = result
        }
    }

    func setInput(_ input: Input, for monitorId: String) {
        guard let idx = monitors.firstIndex(where: { $0.id == monitorId }) else { return }
        let display = monitors[idx].display
        let mode    = monitors[idx].inputMode
        let code    = input.code(for: mode)
        Task.detached(priority: .userInitiated) {
            _ = ddcWriteInput(display, code: code, mode: mode)
        }
    }


    private nonisolated static func discover(config: AppConfig) -> [MonitorState] {
        let displays = discoverExternalDisplays()
        config.registerIfNew(displays)
        return displays.map { display in
            let override = config.override(for: display)
            return MonitorState(
                display: display,
                availableInputs: config.inputEntries(for: override),
                inputMode: override.inputMode
            )
        }
    }
}

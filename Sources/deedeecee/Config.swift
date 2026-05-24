import Foundation
import Yams

struct InputConfig: Sendable {
    let enabled: Bool    // defaults to true when omitted from config
    let alias: String?   // custom menu label; nil = use Input.label default
}

struct InputEntry: Identifiable, Sendable {
    let input: Input
    let label: String
    var id: String { input.id }
}

struct MonitorOverride: Sendable {
    let inputConfigs: [String: InputConfig]?   // nil = show all with default labels
    let inputMode: InputMode
}

struct AppConfig: Sendable {
    let diagnostics: Bool
    let monitors: [String: MonitorOverride]

    static let empty = AppConfig(diagnostics: false, monitors: [:])

    // Try displayId ("GSM-23745") first, then name, then fall back to defaults.
    func override(for display: ExternalDisplay) -> MonitorOverride {
        monitors[display.displayId] ?? monitors[display.name] ?? MonitorOverride(inputConfigs: nil, inputMode: .standard)
    }

    // Build the InputEntry list for a monitor from its override.
    func inputEntries(for override: MonitorOverride) -> [InputEntry] {
        Input.allCases.compactMap { input in
            let cfg = override.inputConfigs?[input.rawValue]
            guard cfg?.enabled ?? true else { return nil }
            let alias = cfg?.alias ?? ""
            let label = alias.isEmpty ? input.label : alias
            return InputEntry(input: input, label: label)
        }
    }

    // Appends entries for any displays not yet present in the config file.
    func registerIfNew(_ displays: [ExternalDisplay]) {
        let newDisplays = displays.filter {
            monitors[$0.displayId] == nil && monitors[$0.name] == nil
        }
        guard !newDisplays.isEmpty else { return }

        let url = AppConfig.configURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = "monitors:\n"
        }
        if !text.hasSuffix("\n") { text += "\n" }

        for display in newDisplays {
            text += "\n"
            text += "  \(display.displayId):  # \(display.name)\n"
            text += "    inputs:\n"
            for input in Input.allCases {
                text += "      \(input.rawValue):\n"
                text += "        enabled: true\n"
            }
            text += "    inputMode: standard\n"
        }

        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    static let configURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/deedeecee/settings.yaml")

    static func createIfMissing() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let template = """
            # deedeecee settings
            # \(configURL.path)
            #
            # diagnostics   Enable verbose DDC logging to stderr.
            #               true | false (default: false)
            #
            # monitors      Per-monitor overrides, keyed by ManufacturerID-ProductID.
            #               Run deedeecee once with a monitor connected to auto-populate.
            #
            #   inputs      Per-input configuration map.
            #               Each key is an input name: displayPort1, displayPort2,
            #               hdmi1, hdmi2, usbC
            #               Omit this key entirely to show all inputs with default labels.
            #               Inputs not listed in the map are shown with their default label.
            #
            #     enabled   Show this input in the submenu. true | false (default: true)
            #     alias     Custom label to show in the menu instead of the default.
            #               Omit to use the default label.
            #
            #   inputMode   DDC addressing mode for this monitor.
            #               standard  VESA DDC/CI — VCP 0x60, I2C addr 0x51 (default)
            #               alt       LG proprietary — VCP 0xF4, I2C addr 0x50
            #
            # Example:
            #
            # diagnostics: false
            #
            # monitors:
            #   GSM-23745:  # LG IPS QHD
            #     inputs:
            #       displayPort1:
            #         enabled: true
            #         alias: "USB-C"
            #       displayPort2:
            #         enabled: false
            #       hdmi1:
            #         enabled: true
            #         alias: "HDMI"
            #       hdmi2:
            #         enabled: false
            #       usbC:
            #         enabled: false
            #     inputMode: standard

            diagnostics: false

            monitors:
            """
        try? template.write(to: configURL, atomically: true, encoding: .utf8)
    }

    static func load() -> AppConfig {
        createIfMissing()
        guard let text = try? String(contentsOf: configURL, encoding: .utf8),
              let root = try? Yams.load(yaml: text) as? [String: Any]
        else { return .empty }

        let diagnostics = (root["diagnostics"] as? Bool) ?? false

        var monitors: [String: MonitorOverride] = [:]
        if let raw = root["monitors"] as? [String: Any] {
            for (name, value) in raw {
                guard let dict = value as? [String: Any] else { continue }
                let inputMode = (dict["inputMode"] as? String).flatMap { InputMode(rawValue: $0) } ?? .standard

                var inputConfigs: [String: InputConfig]? = nil
                if let inputsRaw = dict["inputs"] as? [String: Any] {
                    var configs: [String: InputConfig] = [:]
                    for (inputName, inputValue) in inputsRaw {
                        guard let inputDict = inputValue as? [String: Any] else { continue }
                        let enabled = (inputDict["enabled"] as? Bool) ?? true
                        let alias = inputDict["alias"] as? String
                        configs[inputName] = InputConfig(enabled: enabled, alias: alias)
                    }
                    inputConfigs = configs
                }

                monitors[name] = MonitorOverride(inputConfigs: inputConfigs, inputMode: inputMode)
            }
        }

        return AppConfig(diagnostics: diagnostics, monitors: monitors)
    }
}

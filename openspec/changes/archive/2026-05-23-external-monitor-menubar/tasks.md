## 1. Swift Package Setup

- [x] 1.1 Create `Package.swift` with a single `executableTarget` named `deedeecee` and `platforms: [.macOS(.v13)]`
- [x] 1.2 Create the `Sources/deedeecee/` directory for all Swift source files
- [x] 1.3 Verify `swift build` succeeds before adding UI code
- [x] 1.4 Add Yams dependency to `Package.swift` and add `["Yams"]` to `deedeecee` target dependencies
- [x] 1.5 Add CoreDisplay linker flags: `unsafeFlags(["-framework", "CoreDisplay", "-F", "/System/Library/PrivateFrameworks"])`

## 2. App Shell

- [x] 2.1 Suppress dock icon via `NSApp.setActivationPolicy(.accessory)` in `applicationWillFinishLaunching` using `@NSApplicationDelegateAdaptor`
- [x] 2.2 Add `MenuBarExtra` scene using `display.2` as the label icon
- [x] 2.3 Add `Settings` scene with an empty placeholder view

## 3. Input Model

- [x] 3.1 Define an `Input` enum with cases `displayPort1`, `displayPort2`, `hdmi`, `hdmi2`, `usbC` — `CaseIterable`, `Identifiable`, `Hashable`, with a `label: String` property
- [x] 3.2 Add `ddcCode: UInt16` property mapping to LG alt mode codes (DP1→208, DP2→209, HDMI→144, HDMI2→145, USB-C→210)
- [x] 3.3 Add `standardCode: UInt16` property mapping to VESA DDC/CI codes (DP1→0x0F, DP2→0x10, HDMI→0x11, HDMI2→0x12, USB-C→0x1B)
- [x] 3.4 Add `func code(for mode: InputMode) -> UInt16` selecting between alt and standard codes

## 4. DDC Bridge (Pure Swift)

- [x] 4.1 Implement `DDCKit.swift` with private symbol loading via `dlsym(RTLD_DEFAULT, name)` using `UnsafeMutableRawPointer(bitPattern: -2)` as process handle
- [x] 4.2 Define `ExternalDisplay` struct with `id`, `name`, `displayId`, `supportsActiveOff`, `supportsStandby`, `avProxyPath`
- [x] 4.3 Implement `discoverExternalDisplays()` — single IORegistry pass correlating `IOMobileFramebufferShim` + `DCPAVServiceProxy` by `dispextN` key
- [x] 4.4 Implement `dispextKey(from:separator:)` to extract `dispextN` prefix from IORegistry paths
- [x] 4.5 Define `InputMode` enum with `.alt` and `.standard` cases
- [x] 4.6 Define DDC constants for alt mode (VCP 0xF4, addr 0x50) and standard mode (VCP 0x60, addr 0x51)
- [x] 4.7 Implement `ddcWriteInput(_ display:code:mode:) -> Bool` using mode-appropriate VCP and addr
- [x] 4.8 Implement `ddcDiagnose()` logging symbol resolution, display counts, DisplayAttributes nodes, DCPAVServiceProxy nodes, and discovery results

## 5. Config System

- [x] 5.1 Create `Config.swift` with `MonitorOverride` struct (`inputs: [Input]?`, `inputMode: InputMode`) and `AppConfig` struct with `diagnostics: Bool` and `monitors: [String: MonitorOverride]`
- [x] 5.2 Implement `AppConfig.load()` parsing `~/.config/deedeecee/settings.yaml` via Yams, reading top-level `diagnostics` and `monitors` keys
- [x] 5.3 Implement `AppConfig.override(for display:)` lookup: displayId first, then name, then defaults
- [x] 5.4 Implement `AppConfig.registerIfNew(_:)` appending entries for undiscovered monitors with EDID name as YAML comment
- [x] 5.5 Implement `AppConfig.createIfMissing()` — if `~/.config/deedeecee/settings.yaml` does not exist, write a documented template covering `diagnostics` and all `monitors` keys; call before the first `load()`
- [x] 5.6 Add `nonisolated(unsafe) var ddcVerbose = false` global to `DDCKit.swift`; set it from `config.diagnostics` in `MonitorService.init()` before `ddcDiagnose()`; guard all `fputs` calls in `DDCKit.swift` with `if ddcVerbose`

## 6. Monitor Service

- [x] 6.1 Define `MonitorState` struct with `id`, `name`, `display`, `availableInputs`, `inputMode`
- [x] 6.2 Create `MonitorService` — `@Observable @MainActor` class holding `monitors: [MonitorState]`
- [x] 6.3 Implement `MonitorService.init()` loading config, calling `ddcDiagnose()`, then `refresh()`
- [x] 6.4 Implement `refresh()` dispatching `discover(config:)` to background queue via `withCheckedContinuation`
- [x] 6.5 Implement startup polling: retry `refresh()` every 2 seconds up to 5 times while `monitors` is empty
- [x] 6.6 Subscribe to `NSApplication.didChangeScreenParametersNotification` and call `refresh()` on each event
- [x] 6.7 Implement `nonisolated static func discover(config:) -> [MonitorState]` calling `discoverExternalDisplays()` and `config.registerIfNew()`
- [x] 6.8 Implement `setInput(_:for:)` — detached task calling `ddcWriteInput`
- [x] 6.9 Implement live config reload: in `MonitorService.init()`, open a file descriptor on `settings.yaml` and create a `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:.write, queue: .main)` that calls `AppConfig.load()`, updates `ddcVerbose`, and calls `refresh()` on each write event; hold the source and fd for the lifetime of `MonitorService`

## 7. Menu Content

- [x] 7.1 Wrap the monitor list in `Section("External Monitors") { ... }` for the small-caps section header style
- [x] 7.2 When `service.monitors` is empty, render `Text("none!").foregroundStyle(.secondary)` inside the Section
- [x] 7.3 Render each monitor as `Menu(monitor.name) { ... }`
- [x] 7.4 Inside each monitor menu, render inputs as `Button(input.label)` items using `ForEach(monitor.availableInputs)`
- [x] 7.5 Add `Divider()` after monitor section, then `Button("Settings…")` calling `NSWorkspace.shared.open(configURL)` to open `~/.config/deedeecee/settings.yaml` in the default text editor, followed by `Button("Quit")` with `.keyboardShortcut("q")`

## 8. Display Change Notifications

- [x] 8.1 Subscribe to `NSApplication.didChangeScreenParametersNotification` in `MonitorService.init()` via async `for await` loop
- [x] 8.2 Implement startup polling task in `MonitorService.init()`

## 9. App Bundle and Installation

- [x] 9.1 Create `Resources/Info.plist` with `CFBundleExecutable=deedeecee`, `CFBundleName=deedeecee`, `CFBundleIdentifier=com.deedeecee.app`, `CFBundleVersion=1.0`, `CFBundleShortVersionString=1.0`, `CFBundlePackageType=APPL`, `LSMinimumSystemVersion=13.0`, `LSUIElement=YES`
- [x] 9.2 Create `Makefile` with `build` target: `swift build -c release`, assemble `deedeecee.app/Contents/MacOS/`, copy binary and `Info.plist`, run `codesign --sign - --force deedeecee.app`
- [x] 9.3 Add `install` target to `Makefile`: depends on `build`, copies `deedeecee.app` to `~/Applications/`
- [x] 9.4 Write `README.md` covering: prerequisites (macOS 13+, Swift toolchain), `swift run` dev workflow, `make build` / `make install`, ad-hoc vs Developer ID signing, and first-run `settings.yaml` creation

## 10. Verification

## 11. Input Aliasing and Filtering

- [x] 11.1 Define `InputConfig` struct (`enabled: Bool`, `alias: String?`) and `InputEntry` struct (`input: Input`, `label: String`, `Identifiable` via `input.id`) in `Config.swift`
- [x] 11.2 Replace `MonitorOverride.inputs: [Input]?` with `inputConfigs: [String: InputConfig]?`; update `override(for:)` default
- [x] 11.3 Update `AppConfig.load()` to parse the new `inputs:` map format (each key is an input name, value has optional `enabled` and `alias`)
- [x] 11.4 Update `AppConfig.registerIfNew()` to write the new object map format (all five inputs, each `enabled: true`, no alias)
- [x] 11.5 Update `AppConfig.createIfMissing()` template to document the new `inputs:` map format with `enabled` and `alias` keys
- [x] 11.6 Replace `MonitorState.availableInputs: [Input]` with `availableInputs: [InputEntry]`
- [x] 11.7 Update `MonitorService.discover()` to build `[InputEntry]` — filter `Input.allCases` by `enabled` (default `true` for unlisted), attach alias or default label
- [x] 11.8 Update `MonitorMenuView` `ForEach` to use `InputEntry`: render `entry.label` as button text and pass `entry.input` to `setInput`
- [x] 11.9 Fix label resolution in `AppConfig.inputEntries(for:)`: use `alias` only if non-empty, otherwise fall back to `input.label` (the human-readable default)

## 10. Verification

- [x] 10.1 Run `swift run` and confirm status bar icon appears with no Dock icon
- [x] 10.2 Confirm menu opens with real monitor names discovered via IORegistry
- [x] 10.3 Confirm selecting an input sends DDC write to the monitor
- [x] 10.4 Confirm new monitors are auto-registered in `~/.config/deedeecee/settings.yaml`
- [x] 10.6 Confirm config-restricted input lists hide excluded inputs from submenus
- [x] 10.7 Confirm Quit terminates the app
- [x] 10.8 Run `make install`, confirm `~/Applications/deedeesee.app` is created, signed, and launches correctly
- [x] 10.9 Confirm installed app shows no Dock icon

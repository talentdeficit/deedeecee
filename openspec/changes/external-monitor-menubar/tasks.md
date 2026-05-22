## 1. Swift Package Setup

- [ ] 1.1 Create `Package.swift` with a single `executableTarget` named `deedeecee` and `platforms: [.macOS(.v15)]`
- [ ] 1.2 Create the `Sources/deedeecee/` directory for all Swift source files
- [ ] 1.3 Verify `swift build` succeeds before adding UI code

## 2. App Shell

- [ ] 2.1 Create the `@main` `App` struct with `NSApp.setActivationPolicy(.accessory)` in `init()` to suppress the Dock icon
- [ ] 2.2 Add `MenuBarExtra` scene using `display.2` as the label icon
- [ ] 2.3 Add `Settings` scene with an empty placeholder view

## 3. Monitor List Data

- [ ] 3.1 Define a `Monitor` model struct with a `name: String` property
- [ ] 3.2 Create a hardcoded array of two `Monitor` values: "LG UltraWide" and "LG LCD"

## 4. Menu Content

- [ ] 4.1 Add a `Text("External Monitors")` item styled with `.foregroundStyle(.secondary)` and `.disabled(true)`
- [ ] 4.2 Add a `Divider()` after the header
- [ ] 4.3 Implement a `MonitorRow` view using `Label` with a `ZStack` icon (filled `Circle` + `Image(systemName: "display")`)
- [ ] 4.4 Verify the composite icon renders correctly in `.menu` style; if not, use `ImageRenderer` to produce an `NSImage` fallback
- [ ] 4.5 Add a `ForEach` over the monitor array rendering a `Button` with `MonitorRow` label for each monitor
- [ ] 4.6 Add a second `Divider()` after the monitor list
- [ ] 4.7 Add a `SettingsLink { Text("Settings") }` item
- [ ] 4.8 Add a `Button("Quit") { NSApplication.shared.terminate(nil) }` item

## 5. Verification

- [ ] 5.1 Run `swift run` and confirm status bar icon appears with no Dock icon
- [ ] 5.2 Confirm menu opens with correct item order
- [ ] 5.3 Confirm both monitor rows display icon and name correctly
- [ ] 5.4 Confirm Settings opens a window
- [ ] 5.5 Confirm Quit terminates the app

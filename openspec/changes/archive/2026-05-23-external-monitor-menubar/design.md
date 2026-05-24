## Context

This is a greenfield Mac menu bar app POC named **deedeecee**. There is no existing codebase. The goal is to validate the SwiftUI `MenuBarExtra` API as a foundation for a monitor management utility, with a `swift run` dev workflow (no Xcode required).

## Goals / Non-Goals

**Goals:**
- Validate `MenuBarExtra` with `.menu` style for the intended UI
- Establish a `swift run`-based dev workflow (Swift Package Manager, no Xcode project)
- Read and switch external monitor inputs via DDC/CI using both LG alt mode and standard VESA DDC/CI
- Allow per-monitor overrides via a YAML config file
- Produce an installable `.app` bundle that can be added to macOS Login Items

**Non-Goals:**
- Custom per-row icons (dropped — `Image(nsImage:)` is silently ignored by SwiftUI's `.menu` style renderer)
- Enumerating available inputs from DDC (LG input codes are known statically)
- Settings screen
- App Store distribution or notarization

## Decisions

**Swift Package Manager over Xcode project**
SPM with `swift run` is the dev workflow. No `.xcodeproj` file. `Package.swift` declares a single `executableTarget` named `deedeecee` targeting macOS 13+. The `@main` attribute on the SwiftUI `App` struct provides the entry point.

**Dual dock suppression: `LSUIElement` in bundle + programmatic fallback**
The installed `.app` bundle includes an `Info.plist` with `LSUIElement = YES`, which suppresses the dock icon at the OS level before the app starts. The programmatic `NSApp.setActivationPolicy(.accessory)` call via `@NSApplicationDelegateAdaptor` is retained as a fallback for the `swift run` dev workflow, which produces a plain executable (no bundle) so `Info.plist` is not read by the OS.

**`Info.plist` for the app bundle**
`Resources/Info.plist` declares the minimum keys needed for a valid macOS `.app`:
- `CFBundleExecutable`: `deedeecee`
- `CFBundleName`: `deedeecee`
- `CFBundleIdentifier`: `com.deedeecee.app`
- `CFBundleVersion` / `CFBundleShortVersionString`: `1.0`
- `CFBundlePackageType`: `APPL`
- `LSMinimumSystemVersion`: `13.0`
- `LSUIElement`: `YES`

**`Makefile` build and install workflow**
SPM is used for compilation; a `Makefile` wraps bundle assembly and installation:
- `make build`: `swift build -c release`, creates `deedeecee.app/Contents/MacOS/`, copies binary and `Info.plist`, ad-hoc signs with `codesign --sign -`
- `make install`: runs `build`, then copies `deedeecee.app` to `~/Applications/`

Ad-hoc signing is sufficient for local use.

**SwiftUI `MenuBarExtra` over AppKit `NSStatusItem`**
SwiftUI `MenuBarExtra` (macOS 13+) eliminates manual `NSMenu`/`NSMenuItem` wiring. For a POC, the declarative syntax is faster to iterate on.

**`.menu` style (default) over `.window` style**
The spec calls for a classic dropdown menu, not a popover panel. `.menu` style maps each SwiftUI view to an `NSMenuItem` under the hood.

**Pure Swift DDC implementation over ObjC bridge**
DDC/CI code lives entirely in Swift (`DDCKit.swift`). Private framework symbols (`IOAVServiceReadI2C`, `IOAVServiceWriteI2C`, `IOAVServiceCreateWithService`) are resolved at runtime via `dlsym(RTLD_DEFAULT, name)` — the process handle (`UnsafeMutableRawPointer(bitPattern: -2)`) searches all linked images, including those in the dyld shared cache. `CoreDisplay` is linked via `unsafeFlags` in `Package.swift` so its symbols are present in the process image. This avoids `dlopen` on a path, which fails on macOS 12+ because framework binaries live in the dyld shared cache and are not present as standalone files.

**IORegistry-based display discovery**
Display discovery does a single IORegistry pass (kIOServicePlane, recursive). Two node types are correlated by their shared `dispextN` path prefix:
- `IOMobileFramebufferShim` — carries `DisplayAttributes` (EDID product name, ManufacturerID, ProductID)
- `DCPAVServiceProxy` (Location=External) — carries the IORegistry path used to create an IOAVService for DDC I/O

`discoverExternalDisplays()` returns `[ExternalDisplay]` structs with stable `id` (proxy path), `displayId` ("ManufacturerID-ProductID" e.g. "GSM-23745"), and EDID name.

**`displayId` as stable config key**
Config lookups use `ManufacturerID-ProductID` (e.g. `"GSM-23745"`) as the primary key, with display name as a fallback for backwards compatibility. This is model-level stable — it survives firmware updates and reconnections.

**`InputMode` enum for DDC addressing**
Two modes are supported:
- `.alt` — LG proprietary: VCP `0xF4` at I2C sub-address `0x50`.
- `.standard` — VESA DDC/CI: VCP `0x60` at I2C sub-address `0x51`. Checksum uses `0x51` in XOR.

Default mode for unconfigured monitors is `.standard`.

**Button-based input selection**
The input list uses `ForEach` of plain `Button` items with the input label as text. No active-input tracking or checkmark is shown. Selecting an input (including the currently active one) always fires a DDC write.

**YAML config at `~/.config/deedeecee/settings.yaml`**
Parsed at startup via [Yams](https://github.com/jpsim/Yams). Structure:
```yaml
diagnostics: false

monitors:
  GSM-23745:  # LG UltraWide
    inputs: [displayPort1, displayPort2, hdmi, usbC]
    inputMode: standard
```
Top-level `diagnostics` controls whether DDC operations log to stderr. When `false` (the default), all `fputs` output is suppressed. A `nonisolated(unsafe) var ddcVerbose` global in `DDCKit.swift` is set from `AppConfig.diagnostics` in `MonitorService.init()` before `ddcDiagnose()` is called.

`monitors` keys: `displayId` (primary) or display name (fallback). `inputs` filters the submenu; omitting it shows all five inputs. `inputMode` selects alt vs standard DDC addressing.

**Initial config file creation**
If `~/.config/deedeecee/settings.yaml` does not exist at startup, `AppConfig` creates it with a documented template before the first discovery pass. The template explains every key and valid value, and includes a commented-out example entry. An existing file (even empty) is never overwritten.

**Live config reload via `DispatchSource` file watching**
`MonitorService` opens a file descriptor on `settings.yaml` after the first `load()` and creates a `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:.write, queue: .main)`. On each write event the handler calls `AppConfig.load()` and `refresh()`, then updates `ddcVerbose` from the new config. The source is held for the lifetime of `MonitorService`. If the file does not exist yet (first launch before `createIfMissing()` runs), the watch is set up after the file is created.

**Auto-registration of new monitors**
`AppConfig.registerIfNew(_:)` appends entries for any monitors not already in the config file. Called from the background discovery queue on every refresh. The entry uses all inputs and `standard` mode as defaults. The display name appears as a YAML comment on the identifier line.

**`MonitorService` as the single source of truth**
An `@Observable @MainActor` class `MonitorService` holds `[MonitorState]`. Config is loaded once at init and passed to the background `discover` function. `setInput(_:for:)` fires a DDC write on a detached background task.

**Asynchronous DDC I/O on background queue**
DDC reads include `usleep(10_000)` (10ms) calls and may take 50–200ms per monitor. All DDC I/O runs on a background `DispatchQueue` via `withCheckedContinuation`. UI updates when the main-actor assignment completes.

**`Input` enum maps to both alt and standard codes**
`Input` has `ddcCode: UInt16` (alt mode), `standardCode: UInt16` (standard mode), and `func code(for mode: InputMode) -> UInt16`. Five cases: `displayPort1`, `displayPort2`, `hdmi`, `hdmi2`, `usbC`.

## Risks / Trade-offs

`swift run` builds slowly on first run (full compilation) → acceptable for POC; subsequent runs are incremental

`MenuBarExtra` is macOS 13+ only → Satisfied; target is macOS 13

`NSApp.setActivationPolicy(.accessory)` must be called before the event loop starts → `applicationWillFinishLaunching` via `NSApplicationDelegateAdaptor` is the correct hook; `LSUIElement` in the bundle's `Info.plist` handles the installed case at the OS level

`CoreDisplay` is a private framework → linked via `unsafeFlags`; may break on future macOS versions; acceptable for POC


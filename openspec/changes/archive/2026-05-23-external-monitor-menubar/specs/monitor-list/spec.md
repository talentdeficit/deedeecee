## ADDED Requirements

### Requirement: Monitor header label
The menu SHALL display "External Monitors" as a non-interactive section header using the standard macOS small-caps menu section style (rendered via SwiftUI `Section`, which maps to `NSMenuItem.sectionHeader(title:)`).

#### Scenario: Header is not clickable
- **WHEN** the user clicks "External Monitors"
- **THEN** no action is taken and the menu remains open

### Requirement: Monitor discovery via IORegistry
The menu SHALL discover connected external monitors at launch and whenever the display configuration changes, using IORegistry to find `IOMobileFramebufferShim` + `DCPAVServiceProxy` node pairs. Monitor names SHALL come from the EDID `ProductName` field. Discovery runs asynchronously on a background queue; the menu updates when results are available.

`MonitorService` SHALL subscribe to `NSApplication.didChangeScreenParametersNotification` in its initialiser and call `refresh()` on every change. The initial refresh also happens in the initialiser.

On startup, `MonitorService` SHALL also poll: if after the initial refresh no monitors are found, it SHALL retry `refresh()` every 2 seconds for up to 5 attempts, stopping early once at least one monitor appears.

#### Scenario: Monitors discovered at launch
- **WHEN** the app starts
- **THEN** it discovers all connected external monitors and displays their real EDID product names in the menu

#### Scenario: No external monitors connected
- **WHEN** no external monitors are connected (or discovery has not yet completed)
- **THEN** the "External Monitors" section shows a non-interactive "none!" label rendered in a secondary text style

### Requirement: Input switcher
Each monitor submenu SHALL list the inputs determined by the monitor's config entry (see Requirement: Input aliasing and filtering). If no config entry exists or `inputs` is omitted, all five inputs SHALL be shown with their default labels: DisplayPort 1 (alt: 208, std: 0x0F), DisplayPort 2 (alt: 209, std: 0x10), HDMI 1 (alt: 144, std: 0x11), HDMI 2 (alt: 145, std: 0x12), USB-C (alt: 210, std: 0x1B).

Each input SHALL be rendered as a plain `Button`. The button label SHALL be the input's `alias` if it is a non-empty string, otherwise `Input.label` (the default human-readable label). Selecting an input SHALL send a DDC write using the VCP and I2C address for the monitor's `inputMode`. Selecting the same input again SHALL re-send the DDC command.

#### Scenario: Input options present
- **WHEN** the submenu for a monitor is open
- **THEN** the enabled inputs from the monitor's config are shown (or all five with their `Input.label` defaults if unconfigured)

#### Scenario: Selecting an input
- **WHEN** the user clicks any input option
- **THEN** a DDC write is sent immediately (asynchronously on a detached task)

### Requirement: Input aliasing and filtering
The `inputs:` field under a monitor entry in `settings.yaml` SHALL be a YAML map from input name to a per-input config object. Each input name is one of: `displayPort1`, `displayPort2`, `hdmi1`, `hdmi2`, `usbC`.

Each per-input object supports two optional keys:
- `enabled: true | false` — whether the input appears in the submenu. Defaults to `true` if omitted.
- `alias: "label"` — custom label shown in the menu. If absent or the empty string, `Input.label` (the default human-readable label) is used instead.

Inputs not listed in the map default to `enabled: true` and show `Input.label` as the label (i.e., unlisted inputs are shown with their human-readable default).

Example:
```yaml
monitors:
  GSM-23745:  # LG IPS QHD
    inputs:
      displayPort1:
        enabled: true
        alias: "USB-C"
      displayPort2:
        enabled: false
      hdmi1:
        enabled: true
        alias: "HDMI"
      hdmi2:
        enabled: false
      usbC:
        enabled: false
    inputMode: standard
```

`AppConfig` SHALL parse this map into a `[String: InputConfig]` where `InputConfig` has `enabled: Bool` and `alias: String?`. `MonitorOverride` SHALL replace its former `inputs: [Input]?` field with `inputConfigs: [String: InputConfig]?`. `MonitorService.discover` SHALL filter `Input.allCases` by `enabled` and resolve the label when building `MonitorState.availableInputs`.

Label resolution order: use `alias` if it is a non-empty string; otherwise use `Input.label` (the default human-readable label, e.g. "DisplayPort 1").

`MonitorState.availableInputs` SHALL be a list of `InputEntry` (or equivalent `(input: Input, label: String)`) so the menu can render the resolved label without re-reading config.

#### Scenario: Input hidden via enabled: false
- **WHEN** a monitor's config sets `enabled: false` for an input
- **THEN** that input does not appear in the monitor's submenu

#### Scenario: Input shown with alias
- **WHEN** a monitor's config sets `alias: "USB-C"` for `displayPort1`
- **THEN** the menu button for that input reads "USB-C" but still sends the DisplayPort 1 DDC code

#### Scenario: Input shown with default label when alias is absent
- **WHEN** an input is listed in the map with no `alias` (or `alias: ""`)
- **THEN** the menu button label is `Input.label` (e.g. "DisplayPort 1")

#### Scenario: Input with no config entry shown with default label
- **WHEN** an input is not listed under a monitor's `inputs:` map
- **THEN** it appears in the submenu with its human-readable default label

#### Scenario: Alias updated via live reload
- **WHEN** the user edits an alias in `settings.yaml` and saves
- **THEN** the updated label appears in the submenu on the next menu open

### Requirement: YAML config
`AppConfig` SHALL load `~/.config/deedeecee/settings.yaml` at startup using Yams. It exposes two top-level keys: `diagnostics` and `monitors`.

**`diagnostics: true | false`** — controls whether DDC operations emit verbose logging to stderr. Defaults to `false`. When `true`, `ddcDiagnose()` runs at startup and all DDC write and power commands log their parameters and per-attempt results.

**`monitors`** — maps monitor identifiers to `MonitorOverride` structs with `inputConfigs: [String: InputConfig]?` and `inputMode: InputMode`. Lookup order: `displayId` (e.g. `"GSM-23745"`) → display name → defaults (`inputConfigs: nil`, `inputMode: .standard`). See Requirement: Input aliasing and filtering for the `inputs:` map format.

#### Scenario: Diagnostics disabled by default
- **WHEN** `diagnostics` is `false` or omitted
- **THEN** no DDC logging is emitted to stderr

#### Scenario: Diagnostics enabled
- **WHEN** `diagnostics: true` is set in `settings.yaml`
- **THEN** DDC symbol resolution, IORegistry scan results, and per-attempt write/power results are logged to stderr

#### Scenario: Config restricts visible inputs
- **WHEN** a monitor's config entry has inputs with `enabled: false` for all but `displayPort1` and `usbC`
- **THEN** only those two inputs appear in that monitor's submenu

#### Scenario: Config selects alt DDC mode
- **WHEN** a monitor's config entry has `inputMode: alt`
- **THEN** DDC writes use VCP `0xF4` at I2C address `0x50`

### Requirement: Initial config file creation
On startup, before the first discovery pass, `AppConfig` SHALL check whether `~/.config/deedeecee/settings.yaml` exists. If it does not, the app SHALL create it with a documented template that explains every supported key and its valid values. The template SHALL be human-readable and serve as the primary reference for users editing the file manually.

The template SHALL document:
- The top-level `monitors:` key
- That each sub-key is a monitor identifier in `ManufacturerID-ProductID` format (e.g. `GSM-23745`)
- The `inputs:` map and all valid input keys: `displayPort1`, `displayPort2`, `hdmi1`, `hdmi2`, `usbC`
- That each input entry supports `enabled: true | false` (default `true`) and `alias: "label"` (optional)
- That inputs not listed in the map default to enabled with their default label
- That omitting `inputs:` entirely shows all inputs with default labels
- The `inputMode:` field and its two valid values: `standard` (VESA DDC/CI, VCP 0x60) and `alt` (LG proprietary, VCP 0xF4)
- That `inputMode` defaults to `standard` if omitted

The template SHALL include at least one commented-out example entry so the user can see the exact syntax required.

#### Scenario: File created on first launch
- **WHEN** `~/.config/deedeecee/settings.yaml` does not exist at startup
- **THEN** the file is created with a documented template before any monitor discovery runs

#### Scenario: Existing file not overwritten
- **WHEN** `~/.config/deedeecee/settings.yaml` already exists (with any content, including empty)
- **THEN** the file is left untouched

### Requirement: Live config reload
The app SHALL watch `~/.config/deedeecee/settings.yaml` for changes while running. When the file is modified, the app SHALL reload `AppConfig` and call `refresh()` so that changes to `inputs` (including `enabled` flags and aliases), `inputMode`, and `diagnostics` take effect immediately without restarting.

#### Scenario: Input list updated while running
- **WHEN** the user edits `settings.yaml` to restrict a monitor's inputs and saves
- **THEN** the monitor's submenu updates to reflect the new input list on the next menu open

#### Scenario: Diagnostics toggled while running
- **WHEN** the user changes `diagnostics` from `false` to `true` in `settings.yaml` and saves
- **THEN** subsequent DDC operations emit verbose logging without restarting the app

### Requirement: Auto-registration of new monitors
On every discovery pass, `AppConfig.registerIfNew(_:)` SHALL append entries for any monitors not already present in the config file. New entries SHALL list all five inputs in the object map format with `enabled: true` and no alias, and `inputMode: standard`. The monitor's EDID name SHALL appear as a YAML comment on the identifier line.

#### Scenario: New monitor registered on first connection
- **WHEN** a monitor not in the config file is discovered
- **THEN** an entry is appended to `~/.config/deedeecee/settings.yaml` with all five inputs (each `enabled: true`) and `inputMode: standard`

### Requirement: Settings entry
The menu SHALL include a "Settings…" `Button` that opens `~/.config/deedeecee/settings.yaml` using `NSWorkspace.shared.open(_:)`. This delegates to the system's registered handler for `.yaml` files, which is typically the default text editor. The file is guaranteed to exist because `AppConfig.createIfMissing()` runs before the first refresh.

#### Scenario: Settings opens the config file
- **WHEN** the user clicks "Settings…"
- **THEN** `~/.config/deedeecee/settings.yaml` opens in the default application for YAML files

### Requirement: Quit entry
The menu SHALL include a "Quit" `Button` with `.keyboardShortcut("q")` that calls `NSApplication.shared.terminate(nil)`.

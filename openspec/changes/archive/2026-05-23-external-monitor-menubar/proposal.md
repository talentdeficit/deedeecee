## Why

Mac users with LG external monitors need a quick way to see which displays are connected and switch inputs without touching the monitor's physical buttons. A lightweight menu bar app surfaces this at a glance using DDC/CI to communicate with the display directly.

## What Changes

- New macOS menu bar app named **deedeecee** (all lowercase), built with Swift Package Manager
- Runnable via `swift run` — no Xcode project required
- Status bar icon using the `display.2` SF Symbol
- Menu lists all connected external monitors discovered via IORegistry (real EDID names, not hardcoded)
- Each monitor name opens a submenu with configurable inputs: DisplayPort 1, DisplayPort 2, HDMI 1, HDMI 2, USB-C
- For LG monitors in alt mode, the currently active input is read from the monitor via DDC and shown with a checkmark
- Selecting an input sends a DDC write; selecting an already-active input re-sends the command
- Wake and Sleep buttons per monitor, auto-enabled based on IOKit capability flags
- After switching inputs, a DDC wake command is sent automatically (if the monitor supports it)
- Per-monitor YAML config file at `~/.config/deedeecee/settings.yaml` for input list and DDC mode overrides
- New monitors are automatically registered in the config file on first connection
- Quit entry terminates the app, with a ⌘Q keyboard shortcut

## Capabilities

### New Capabilities

- `menu-bar-presence`: Status bar item with SF Symbol icon and dropdown menu
- `monitor-list`: Real-time monitor discovery, input reading, input switching, wake/sleep via DDC/CI
- `ddc-bridge`: Pure-Swift DDC/CI implementation using IORegistry + private IOAVService APIs
- `app-shell`: App entry point and Quit action

### Modified Capabilities

## Impact

- New Swift/SwiftUI package named `deedeecee`, targeting macOS 13+ (tested on macOS 15 Sequoia)
- Build system: Swift Package Manager, single executable target with Yams dependency
- Bridges private Apple APIs: `IOAVServiceReadI2C`, `IOAVServiceWriteI2C` via RTLD_DEFAULT symbol lookup
- IORegistry used for display discovery: correlates `IOMobileFramebufferShim` + `DCPAVServiceProxy` nodes
- YAML config at `~/.config/deedeecee/settings.yaml`; new monitors auto-registered on first connection
- No data persistence beyond the config file

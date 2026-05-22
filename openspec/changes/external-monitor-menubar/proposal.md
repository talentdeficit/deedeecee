## Why

Mac users with external monitors need a quick way to see which displays are connected without opening System Settings. A lightweight menu bar app surfaces this at a glance.

## What Changes

- New macOS menu bar app named **deedeecee** (all lowercase), built with Swift Package Manager
- Runnable via `swift run` — no Xcode project required
- Status bar icon using the `display.2` SF Symbol
- Menu shows a static list of connected monitors (hardcoded for POC: LG UltraWide, LG LCD)
- Each monitor row displays a composite icon (monitor symbol inscribed in a filled circle) alongside the monitor name
- Settings entry opens a separate `Settings` window scene
- Quit entry terminates the app

## Capabilities

### New Capabilities

- `menu-bar-presence`: Status bar item with SF Symbol icon and dropdown menu
- `monitor-list`: Display of connected monitor names with custom icon rows
- `app-shell`: App entry point, scene setup, Settings window, and Quit action

### Modified Capabilities

## Impact

- New Swift/SwiftUI package named `deedeecee`, targeting macOS 15 (Sequoia)
- Build system: Swift Package Manager; dev workflow is `swift run`
- No external dependencies — AppKit/SwiftUI only
- No data persistence for POC

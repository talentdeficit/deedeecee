## Context

This is a greenfield Mac menu bar app POC named **deedeecee**. There is no existing codebase. The goal is to validate the SwiftUI `MenuBarExtra` API as a foundation for a monitor management utility, with a `swift run` dev workflow (no Xcode required).

## Goals / Non-Goals

**Goals:**
- Validate `MenuBarExtra` with `.menu` style for the intended UI
- Prove the composite icon approach (SF Symbol inside filled circle) works within menu item labels
- Establish a `swift run`-based dev workflow (Swift Package Manager, no Xcode project)

**Non-Goals:**
- Real monitor detection (hardcoded data only)
- Persistence or user preferences
- Settings screen content (shell only)
- Distribution or signing

## Decisions

**Swift Package Manager over Xcode project**
SPM with `swift run` is the dev workflow. No `.xcodeproj` file. `Package.swift` declares a single `executableTarget` named `deedeecee` targeting macOS 15 (Sequoia). The `@main` attribute on the SwiftUI `App` struct provides the entry point.

**Programmatic dock suppression over `LSUIElement` in Info.plist**
`swift run` produces a plain executable, not an `.app` bundle, so `LSUIElement` in Info.plist is not read by the OS. Dock icon suppression is done by calling `NSApp.setActivationPolicy(.accessory)` in the `App` struct's `init()` instead. This works regardless of bundle context.

**SwiftUI `MenuBarExtra` over AppKit `NSStatusItem`**
SwiftUI `MenuBarExtra` (macOS 13+) eliminates manual `NSMenu`/`NSMenuItem` wiring. For a POC, the declarative syntax is faster to iterate on. Downside: less control over exact item sizing and highlight behaviour — acceptable for this stage.

**`.menu` style (default) over `.window` style**
The spec calls for a classic dropdown menu, not a popover panel. `.menu` style maps each SwiftUI view to an `NSMenuItem` under the hood. Chosen over `.window` because the UX goal is a standard macOS menu, not a custom HUD.

**Composite icon via `ZStack` in `Label` icon slot**
The monitor-in-circle icon is composed at runtime using a `ZStack` with a filled `Circle` and an `Image(systemName:)`. This is the simplest SwiftUI approach. If `.menu` style strips the ZStack (known limitation: complex icon views may not render in NSMenuItem), the fallback is to render the composite to `NSImage` using `ImageRenderer` and wrap it in `Image(_: nsImage:)`.

**Hardcoded monitor list**
POC only. Monitor names (`LG UltraWide`, `LG LCD`) are defined as a static array in the app. No `CoreDisplay` or `CGDirectDisplay` integration in this iteration.

**`Settings` scene opened via `SettingsLink`**
`SettingsLink` is the idiomatic SwiftUI approach and is available on macOS 14+. Targeting Sequoia (15), this is the preferred choice — no manual selector needed.

## Risks / Trade-offs

`swift run` builds slowly on first run (full compilation) → acceptable for POC; subsequent runs are incremental

Complex SwiftUI views as `Label` icons may not render in `.menu` style → Fallback: `ImageRenderer` → `NSImage` → `Image(_: nsImage:)` wrapper

`MenuBarExtra` is macOS 13+ only → Satisfied; target is macOS 15

`NSApp.setActivationPolicy(.accessory)` must be called before the event loop starts → placing it in `App.init()` should be early enough, but if the dock icon flashes briefly on launch this may need moving earlier

## Open Questions

- Does the `ZStack` composite icon render correctly in `.menu` style on macOS 13/14/15? Needs empirical verification during implementation.
- What accent color for the monitor icon circle? Default `.accentColor` for now.

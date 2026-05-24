## Requirements

### Requirement: Menu-bar-only app
The app SHALL run without a dock icon or main application window. The only persistent UI SHALL be the status bar item. The app SHALL be named **deedeecee** (all lowercase) and built as a Swift Package runnable via `swift run`.

#### Scenario: No dock icon at launch
- **WHEN** the app is started with `swift run`
- **THEN** no icon appears in the Dock

### Requirement: Quit entry
The menu SHALL include a "Quit" item with a ⌘Q keyboard shortcut that terminates the application.

#### Scenario: App quits on click
- **WHEN** the user clicks "Quit"
- **THEN** the application terminates and the status bar icon disappears

#### Scenario: App quits via shortcut
- **WHEN** the user presses ⌘Q while the menu is open
- **THEN** the application terminates

### Requirement: App bundle
The project SHALL include a `Resources/Info.plist` and a `Makefile` that produce an installable `deedeecee.app` bundle from the SPM release build.

`Info.plist` SHALL declare:
- `CFBundleExecutable`: `deedeecee`
- `CFBundleName`: `deedeecee`
- `CFBundleIdentifier`: `com.deedeecee.app`
- `CFBundleVersion` and `CFBundleShortVersionString`: `1.0`
- `CFBundlePackageType`: `APPL`
- `LSMinimumSystemVersion`: `13.0`
- `LSUIElement`: `YES` (suppresses Dock icon at OS level for the installed bundle)

The `Makefile` SHALL provide two targets:
- `build` — runs `swift build -c release`, creates `deedeecee.app/Contents/MacOS/`, copies the binary and `Info.plist`, then ad-hoc signs the bundle with `codesign --sign -`
- `install` — runs `build`, then copies `deedeecee.app` to `~/Applications/`

#### Scenario: Install produces a valid bundle
- **WHEN** the user runs `make install`
- **THEN** `~/Applications/deedeecee.app` exists, is ad-hoc signed, and launches correctly when double-clicked

#### Scenario: Bundle suppresses Dock icon
- **WHEN** the installed `deedeecee.app` is launched
- **THEN** no icon appears in the Dock (handled by `LSUIElement = YES` in `Info.plist`)

### Requirement: README
`README.md` SHALL document everything a new user needs to build and install the app from source. It SHALL cover:
- Prerequisites: minimum macOS version, required Swift toolchain version
- Development workflow: how to run the app with `swift run`
- Building a release bundle: `make build` and what it produces
- Installation: `make install` and where the app is placed
- Code signing: explanation that `make build` applies ad-hoc signing (sufficient for local use and Login Items), and what to do for sharing with others (replace `--sign -` with a Developer ID identity)
- First-run behaviour: that `~/.config/deedeecee/settings.yaml` is created automatically on first launch

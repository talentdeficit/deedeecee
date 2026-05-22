## ADDED Requirements

### Requirement: Menu-bar-only app
The app SHALL run without a dock icon or main application window. The only persistent UI SHALL be the status bar item. The app SHALL be named **deedeecee** (all lowercase) and built as a Swift Package runnable via `swift run`.

#### Scenario: No dock icon at launch
- **WHEN** the app is started with `swift run`
- **THEN** no icon appears in the Dock

### Requirement: Settings entry
The menu SHALL include a "Settings" item that opens a macOS Settings/Preferences window.

#### Scenario: Settings window opens
- **WHEN** the user clicks "Settings"
- **THEN** a Settings window appears

### Requirement: Quit entry
The menu SHALL include a "Quit" item that terminates the application.

#### Scenario: App quits
- **WHEN** the user clicks "Quit"
- **THEN** the application terminates and the status bar icon disappears

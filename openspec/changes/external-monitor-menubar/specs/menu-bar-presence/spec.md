## ADDED Requirements

### Requirement: Status bar icon
The app SHALL display a persistent icon in the macOS status bar using the SF Symbol `display.2`.

#### Scenario: Icon visible at launch
- **WHEN** the app launches
- **THEN** the `display.2` SF Symbol appears in the macOS status bar

#### Scenario: Menu opens on click
- **WHEN** the user clicks the status bar icon
- **THEN** the monitor menu appears as a dropdown below the icon

### Requirement: Menu structure
The menu SHALL contain items in the following order: a header label, a separator, the monitor list, a separator, Settings, and Quit.

#### Scenario: Correct item order
- **WHEN** the menu is open
- **THEN** items appear top-to-bottom as: "External Monitors" label, separator, monitor rows, separator, Settings, Quit

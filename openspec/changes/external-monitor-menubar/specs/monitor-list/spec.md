## ADDED Requirements

### Requirement: Monitor header label
The menu SHALL display "External Monitors" as a non-interactive header above the monitor list, rendered in a secondary (greyed) style.

#### Scenario: Header is not clickable
- **WHEN** the user clicks "External Monitors"
- **THEN** no action is taken and the menu remains open

### Requirement: Monitor rows
The menu SHALL display one row per connected monitor. For the POC, the list SHALL be hardcoded to: "LG UltraWide" and "LG LCD".

#### Scenario: Both monitors appear
- **WHEN** the menu opens
- **THEN** two monitor rows are shown: "LG UltraWide" and "LG LCD", in that order

### Requirement: Monitor row icon
Each monitor row SHALL display a composite icon consisting of the `display` SF Symbol inscribed inside a filled circle, rendered to the left of the monitor name.

#### Scenario: Icon renders with name
- **WHEN** a monitor row is visible
- **THEN** the row shows a filled circle containing a display icon, followed by the monitor name as text

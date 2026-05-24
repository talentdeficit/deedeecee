## Requirements

### Requirement: Pure-Swift DDC/CI implementation
DDC/CI communication SHALL be implemented entirely in Swift in `DDCKit.swift`. There SHALL be no separate ObjC target. Private framework symbols (`IOAVServiceCreateWithService`, `IOAVServiceWriteI2C`) SHALL be resolved at runtime via `dlsym` using `RTLD_DEFAULT` (represented as `UnsafeMutableRawPointer(bitPattern: -2)`), which searches all images linked into the process including those in the dyld shared cache.

#### Scenario: Private symbols resolved at startup
- **WHEN** the app launches
- **THEN** `IOAVServiceCreateWithService` and `IOAVServiceWriteI2C` function pointers are non-nil, confirming CoreDisplay is linked and symbols are available

### Requirement: Link CoreDisplay via linker flags
`Package.swift` SHALL link `CoreDisplay` via `unsafeFlags(["-framework", "CoreDisplay", "-F", "/System/Library/PrivateFrameworks"])` on the `deedeecee` executable target. This places CoreDisplay symbols in the process image so `dlsym(RTLD_DEFAULT, ...)` can find them.

### Requirement: IORegistry-based display discovery
`discoverExternalDisplays() -> [ExternalDisplay]` SHALL perform a single recursive IORegistry pass on `kIOServicePlane`. It SHALL collect two node types and correlate them by their shared `dispextN` path prefix:
- `IOMobileFramebufferShim`: provides `DisplayAttributes` dict (EDID name, ManufacturerID, ProductID, SupportsActiveOff, SupportsStandby)
- `DCPAVServiceProxy` with `Location == "External"`: provides the IORegistry path for IOAVService creation

`dispextKey(from:separator:)` extracts the `dispextN` prefix from a path component that starts with "dispext" and contains the given separator character (`@` for Shim paths, `:` for Proxy paths).

#### Scenario: Real EDID names returned
- **WHEN** `discoverExternalDisplays()` is called with an LG monitor connected
- **THEN** the returned `ExternalDisplay.name` contains the monitor's EDID product name (e.g., "LG ULTRAFINE") sourced from `DisplayAttributes["ProductAttributes"]["ProductName"]`

#### Scenario: Stable display identifier
- **WHEN** `discoverExternalDisplays()` is called
- **THEN** each `ExternalDisplay.displayId` is in the form `"ManufacturerID-ProductID"` (e.g., `"GSM-23745"`), stable across reconnections and firmware updates

### Requirement: ExternalDisplay struct
`ExternalDisplay` SHALL be a `Sendable` struct with:
- `id: String` — IORegistry proxy path (session-stable, used as SwiftUI identifier)
- `name: String` — EDID product name
- `displayId: String` — `"ManufacturerID-ProductID"` (model-level stable identifier)
- `supportsActiveOff: Bool` — IOKit `SupportsActiveOff` flag (DDC sleep capability)
- `supportsStandby: Bool` — IOKit `SupportsStandby` flag (DDC wake capability)
- `avProxyPath: String` (fileprivate) — IORegistry path used to create the IOAVService

### Requirement: InputMode enum
`InputMode` SHALL be a `String` `Sendable` enum with two cases:
- `.alt` — LG proprietary: VCP `0xF4` at I2C sub-address `0x50`.
- `.standard` — VESA DDC/CI: VCP `0x60` at I2C sub-address `0x51`. Checksum XOR includes `0x51`.

### Requirement: DDC input write
`ddcWriteInput(_ display: ExternalDisplay, code: UInt16, mode: InputMode) -> Bool` SHALL write the given input code using the VCP code and I2C address for the given mode (VCP `0xF4`/`0x50` for alt; VCP `0x60`/`0x51` for standard). Returns `true` on success.

#### Scenario: Selecting an input in alt mode
- **WHEN** `ddcWriteInput` is called with mode `.alt`
- **THEN** VCP `0xF4` is used at I2C address `0x50`, with two retries and `usleep(10_000)` between each

#### Scenario: Selecting an input in standard mode
- **WHEN** `ddcWriteInput` is called with mode `.standard`
- **THEN** VCP `0x60` is used at I2C address `0x51`; the DDC/CI checksum XOR uses `0x51`

### Requirement: DDC wake command
`ddcWake(_ display: ExternalDisplay) -> Bool` SHALL send VCP `0xD6` with value `0x01` (Power On) at I2C address `0x50`.

### Requirement: DDC sleep command
`ddcSleep(_ display: ExternalDisplay) -> Bool` SHALL send VCP `0xD6` with value `0x04` then `0x05` (both DPMS-off variants used for LG firmware compatibility) at I2C address `0x50`. Returns `true` if either write succeeded.

### Requirement: Diagnostics
`ddcDiagnose()` SHALL log to stderr:
- Whether each private symbol was resolved
- Online display count from `CGGetOnlineDisplayList`
- All IORegistry nodes carrying `DisplayAttributes`, formatted as YAML-comment style: `ManufacturerID-ProductID:  # ProductName (activeOff=bool standby=bool)`
- All `DCPAVServiceProxy` nodes with their `Location` property and path
- The result of `discoverExternalDisplays()`

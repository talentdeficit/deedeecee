# deedeecee

macOS menu bar app for switching inputs on external monitors via DDC/CI.

## Prerequisites

- macOS 13 (Ventura) or later
- Swift toolchain — install via [swift.org](https://www.swift.org/install/) or Xcode

Verify your Swift version:

```
swift --version
```

## Development

Run directly from the project directory without building an app bundle:

```
swift run
```

The status bar icon appears immediately. The app reads `~/.config/deedeecee/settings.yaml` at startup, creating it with a documented template if it does not exist.

## Build and Install

Assemble a release `.app` bundle and install it to `~/Applications`:

```
make install
```

This runs the following steps:
1. `swift build -c release` — compiles an optimised binary
2. Assembles `deedeecee.app` with the release binary and `Resources/Info.plist`
3. Ad-hoc signs the bundle with `codesign --sign -`
4. Copies `deedeecee.app` to `~/Applications/`

To build the bundle without installing:

```
make build
```

To remove the built bundle and `.build` directory:

```
make clean
```

## Code Signing

`make build` applies **ad-hoc signing** (`codesign --sign -`). This is sufficient for local use and for registering the app as a Login Item via the "Launch at Login" menu toggle.

Ad-hoc-signed apps cannot be distributed to other Macs. To share the app, sign with a Developer ID certificate:

```
codesign --sign "Developer ID Application: Your Name (TEAMID)" --force deedeecee.app
```

Replace the identity string with one from your keychain (`security find-identity -v -p codesigning`).

## Login Items

Once installed, enable "Launch at Login" from the app's menu. This calls the macOS `SMAppService` API to register the app as a Login Item — no trip to System Settings required.

The toggle is disabled when running via `swift run` (no bundle), and only functional for the installed app.

## Configuration

Settings are stored in `~/.config/deedeecee/settings.yaml`. The file is created automatically on first launch with inline documentation. Open it from the app menu via **Settings…**.

Key options:

```yaml
diagnostics: false   # set to true to log DDC activity to stderr

monitors:
  GSM-23745:         # keyed by ManufacturerID-ProductID
    inputs: [displayPort1, displayPort2, usbC]
    inputMode: standard   # or: alt (LG proprietary VCP 0xF4)
```

New monitors are appended to the file automatically when first detected.

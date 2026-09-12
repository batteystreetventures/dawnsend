# DawnSend

Keep the Mac awake. Hit Send at the time you choose.

DawnSend is a native macOS menu-bar utility that keeps the Mac awake and, at a time you choose, submits a message you already drafted in Codex, Cursor, or Claude Cowork.

V1 is local-only, MIT-licensed, and distributed from GitHub Releases. It does not include a Mac App Store build, accounts, servers, analytics, telemetry, or prompt capture.

## Requirements

- macOS 13 or later
- Swift 5.9+ / Xcode command-line tools to build from source

## Build and test

From a clean checkout:

```sh
./scripts/test.sh
./scripts/build.sh
```

The build script writes `dist/DawnSend.app` (display name DawnSend, bundle identifier `app.dawnsend`, no Dock icon).

Open the menu-bar app:

```sh
open dist/DawnSend.app
```

Quit from the popover, or:

```sh
killall DawnSend
```

## Status

The menu-bar popover is wired to the scheduler, keep-awake assertions, and local Send pipeline. Choose Codex, Cursor, or Claude Cowork, set an exact date/time or a relative delay, then Arm. DawnSend acts on the already-open conversation and focused draft. V1 does not keep the Mac awake with the lid closed or the Mac locked.

Diagnose detected apps without sending:

```sh
./dist/DawnSend.app/Contents/MacOS/DawnSend --diagnose
```

See `PromptDocs/` for the staged build plan. Those documents stay in the repository throughout development.

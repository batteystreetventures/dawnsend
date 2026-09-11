# DawnSend

**Work in progress.** This repository is not a finished product yet.

Keep the Mac awake. Hit Send at the time you choose.

DawnSend will be a native macOS menu-bar utility that keeps the Mac awake and, at a time you choose, submits a message you already drafted in Codex, Cursor, or Claude Cowork.

V1 is local-only, MIT-licensed, and distributed from GitHub Releases. It will not include a Mac App Store build, accounts, servers, analytics, telemetry, or prompt capture.

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

Open the placeholder menu-bar app:

```sh
open dist/DawnSend.app
```

Quit from the popover, or:

```sh
killall DawnSend
```

## Status

The current tree is the foundation: a launchable menu-bar placeholder, architecture seams for scheduling, power assertions, target automation, persistence, and notifications, plus local scripts and GitHub Actions CI.

See `PromptDocs/` for the staged build plan. Those documents stay in the repository throughout development.

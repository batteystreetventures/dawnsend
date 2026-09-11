# Prompt 1 of 6: Foundation and GitHub

Build the foundation of **DawnSend** in the current repository. Work autonomously: inspect the repository first, make reasonable implementation choices, and do not ask me to run commands or edit files that you can handle. Only stop for a genuine authentication/authorization blocker or a product decision that materially changes the locked scope.

## Product contract

DawnSend is a native macOS menu-bar utility with the tagline:

> Keep the Mac awake. Hit Send at the time you choose.

It will eventually let a user choose Codex, Cursor, or Claude Cowork; keep the Mac awake; and at a selected time submit a message the user already drafted in that target app.

Locked decisions:

- Display name: `DawnSend`
- GitHub repository: `dawnsend`
- Bundle identifier: `app.dawnsend`
- macOS 13+
- Native Swift + SwiftUI, with AppKit/CoreGraphics/Accessibility and native power assertions where needed
- Menu-bar-only app; no Dock icon
- MIT open source and direct GitHub Releases
- No Mac App Store, server, account, analytics, telemetry, prompt capture, or external runtime

Read `PromptDocs/README.md` before working. Preserve the prompt documents throughout the build.

## Stage goals

1. Inspect the empty/new repository and local Swift/Xcode toolchain.
2. Choose the smallest maintainable native project structure. Prefer a Swift Package executable plus deterministic scripts that produce a real `.app`, unless the available toolchain gives a concrete reason an Xcode project is more reliable.
3. Scaffold a launchable SwiftUI `MenuBarExtra` app:
   - no normal app window and no Dock icon;
   - a neutral SF Symbol in the menu bar;
   - a compact placeholder popover that says DawnSend and shows the tagline;
   - a Quit action;
   - bundle identifier `app.dawnsend`;
   - deployment target macOS 13.
4. Establish a clean architecture sized for V1, with separate areas for:
   - application/UI;
   - scheduling state;
   - power assertion management;
   - target app definitions and send automation;
   - persistence and notifications.
   Do not implement later stages prematurely, but define testable seams/protocols where useful.
5. Add:
   - `.gitignore`;
   - MIT `LICENSE`;
   - a concise initial `README.md` clearly marked work in progress;
   - build and test scripts that work from a clean checkout;
   - an initial unit-test target and at least one meaningful passing test;
   - GitHub Actions CI on macOS that runs the same build/tests.
6. Build and run all tests locally. Fix failures rather than documenting them away.

## GitHub work

Use my currently authenticated GitHub account and create a new **public** repository named `dawnsend` from this existing local repository.

- Use `gh` for GitHub operations.
- Keep the branch named `main`.
- Do not create a feature branch or pull request.
- If a remote already exists, inspect it and avoid replacing it blindly.
- If `dawnsend` already exists in my account, verify it is the intended empty repository before connecting it; otherwise stop and explain the collision.
- If GitHub authentication is definitively unavailable, complete all local work and give me only the exact login step needed. Do not invent another host.

Commit all stage-one work with a clear message and push with:

```sh
git push origin main
```

Confirm the remote repository URL and CI state. If CI has started, you may check its result once and fix an immediate configuration failure; do not enter an open-ended monitoring loop.

## Acceptance criteria

- A clean checkout can build the app and run tests using documented commands.
- The generated app has display name DawnSend, identifier `app.dawnsend`, and does not appear in the Dock.
- Opening it produces a menu-bar item and working popover/quit action.
- CI configuration is valid.
- The repository is public on my GitHub, connected as `origin`, committed, and pushed to `main`.
- No secrets, local build products, `.env` files, user paths, or signing credentials are committed.

## End-of-run handoff

Finish with:

1. A concise summary of what you implemented and verified.
2. Links to the GitHub repository and any completed Actions run.
3. Exact commands I can use to build, install/open, and quit the placeholder app.
4. A numbered list of manual actions I must perform, if any. Keep this list limited to actions you cannot perform, such as completing GitHub authentication or visually confirming the menu-bar item.
5. A clear statement: either **“Ready for Prompt 2”** or what must be fixed first.

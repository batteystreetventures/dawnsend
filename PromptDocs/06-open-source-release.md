# Prompt 6 of 6: Open-source release

Finish and publish **DawnSend V1** from the current repository. Read `PromptDocs/README.md`, the complete source/history, and `docs/verification.md`.

Work autonomously and complete every GitHub/build task available to you. Do not create a feature branch or pull request; use `main`.

## Release gate

Before publishing:

- require all automated checks to pass;
- inspect the Prompt 5 manual verification record;
- if manual results are missing or contain a failure that affects the release claims, ask me only for the missing result or fix the failure before proceeding;
- verify repository status is clean and `main` is synchronized with `origin/main`;
- verify the app still does not capture/store prompts and does not claim lid-closed, locked-screen, or Mac App Store support.

Do not publish a knowingly broken or misleading release merely to finish the prompt.

## Open-source repository polish

Complete the public repository:

- final `README.md` with:
  - DawnSend name and tagline;
  - the concrete 5-hour rolling-window motivation, while making clear DawnSend works at every hour;
  - a short demo/user flow;
  - supported targets: Codex, Cursor, Claude Cowork;
  - requirements and Accessibility permission explanation;
  - installation from GitHub Releases and source;
  - exact Test Send guidance;
  - limitations and troubleshooting links;
  - local-only privacy statement;
  - non-affiliation with OpenAI, Anthropic, and Cursor;
  - comparison to generic `caffeinate`/Keyboard Maestro and the materially different Iverson’s WorkTool without disparaging either;
  - development/test commands;
  - MIT license badge and macOS/CI badges where accurate.
- `CHANGELOG.md` with a `0.1.0` entry.
- `CONTRIBUTING.md` with a small, practical development and target-definition contribution process.
- `SECURITY.md` explaining responsible disclosure and why Accessibility-enabled binaries must be trusted.
- Retain useful architecture/privacy/troubleshooting/verification docs.

Avoid inflated claims such as “guaranteed,” “exact to the millisecond,” or “bypasses limits.” DawnSend schedules a user-authorized local action; it does not increase, evade, or manipulate vendor quotas.

If you can capture a clean screenshot of the popover without exposing private content or the desktop, add it to `docs/screenshots/` and embed it in the README. Do not block the release solely on a screenshot.

## Packaging

Make the release process deterministic:

- clean release build;
- package a correctly named `DawnSend.app`;
- validate its identifier (`app.dawnsend`), version (`0.1.0`), minimum macOS version, LSUIElement/menu-bar behavior, and executable linkage;
- ensure test fixtures, PromptDocs, private logs, and source-only files are not inside the app bundle;
- produce `DawnSend-0.1.0-macOS.zip`;
- produce a SHA-256 checksum;
- use an ad-hoc signature if no Developer ID identity is available, and describe Gatekeeper behavior honestly;
- never access, export, or commit signing secrets.

Prefer a universal binary when the installed toolchain can produce and validate both arm64 and x86_64 without fragile hacks. Otherwise publish the actual architecture in the asset name and documentation.

Add or finalize a tag-driven GitHub Actions release workflow if it can reproducibly build the same artifact. The workflow must not depend on repository secrets for V1 unless a signing identity genuinely exists.

## Publish

1. Run the full test/build/validation suite.
2. Update version files consistently to `0.1.0`.
3. Review `git diff`, `git status`, and staged files.
4. Commit release preparation and push:

```sh
git push origin main
```

5. Tag the exact verified commit `v0.1.0` and push the tag.
6. Use `gh` to create a public GitHub Release with concise notes, install instructions, limitations, the correct app archive, and checksum.
7. Configure the GitHub repository description and useful topics such as `macos`, `swift`, `swiftui`, `menu-bar`, `codex`, `cursor`, `claude`, and `accessibility`.
8. Confirm the release page and downloadable asset metadata.

Do not publish to the Mac App Store, create a paid product, add telemetry, or create a separate website.

If GitHub authorization blocks only the external publish step, finish and verify all local artifacts, then give me the single exact authentication action needed and the commands you will run after I complete it. Resume publishing in the same chat afterward.

## Acceptance criteria

- V1 meets every definition-of-done item in `PromptDocs/README.md`.
- Source and release docs are accurate, concise, and trustworthy.
- Clean build/tests and bundle validation pass.
- `main` contains the release commit.
- Public tag `v0.1.0` points at that commit.
- GitHub Release contains the tested app archive and checksum.
- No secret, private content, or generated development noise is committed.

## End-of-run operator checklist

Finish with a numbered checklist that includes:

1. GitHub repository, commit, tag, Actions, and Release links.
2. What you tested automatically and what was manually verified.
3. Exact steps to download, unzip, open, and grant Accessibility permission.
4. Exact first-use steps: open the target conversation, draft a harmless message, focus the composer, Test Send, then arm a real schedule.
5. How to disarm and quit safely.
6. How to report a bug without attaching prompt text or private Accessibility dumps.
7. Any Gatekeeper/architecture limitation users will see.

End with a direct statement of whether **DawnSend V1 is released**. If not, identify the one remaining blocker and the next action.

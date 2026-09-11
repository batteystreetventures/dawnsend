# Prompt 3 of 6: Target app automation

Continue building **DawnSend** in the current repository. Read `PromptDocs/README.md`, inspect all existing code/tests/history, and preserve the scheduler and power-management behavior from earlier prompts.

Implement the real local Send pipeline for Codex, Cursor, and Claude Cowork. Work autonomously. Do not create a feature branch or pull request.

## Non-negotiable safety model

DawnSend never stores or types the user’s prompt. The user drafts a message in the correct existing conversation, leaves that composer focused, and arms DawnSend.

Never:

- navigate to a different conversation;
- click by hard-coded screen coordinates;
- scrape quota data or call vendor APIs;
- auto-approve agent tool calls;
- send clipboard contents;
- claim a message was successfully sent merely because a synthetic key event was posted.

## Target definitions

Create data-driven target definitions for:

- **Codex**: prefer the current Codex desktop app/bundle when installed; account for the fact that some versions expose a ChatGPT process/app identity.
- **Cursor**: bundle identifier commonly `com.todesktop.230313mzl4w4u92`.
- **Claude Cowork**: Claude Desktop in its already-open Cowork session.

Do not blindly trust those identifiers. Inspect installed applications on this Mac to establish current bundle identifiers where possible, support a short ordered fallback list, and keep definitions isolated so vendor changes require a small patch.

Each target should expose:

- display name and icon metadata;
- candidate bundle identifiers/process names;
- preferred submit key strategy;
- accessible Send/Submit button label candidates;
- diagnostics explaining not installed, not running, wrong frontmost state, or no focused composer.

V1 does not navigate to Cowork mode. It activates Claude Desktop and acts on the session the user deliberately left open.

## Accessibility permission

Implement:

- a non-prompting permission status check;
- a user-initiated request using the supported macOS Accessibility trust API;
- a deep link/button action for the correct System Settings privacy pane;
- clear differentiation between not determined/denied and other automation failures.

Do not request Screen Recording or administrator/root access.

## Send pipeline

Implement a conservative pipeline:

1. Resolve the selected target to an installed application.
2. Require it to be running; do not launch a closed app into an unknown conversation.
3. Require Accessibility permission.
4. Activate the app and wait a bounded period for it to become frontmost.
5. Inspect the target process’s Accessibility tree enough to confirm that an editable composer is focused. If readable, require non-empty content. If the framework does not expose content, report that verification limitation explicitly.
6. Submit using the target’s preferred Return key event.
7. If the key strategy is unsupported or observably did not submit, use `AXPress` on an accessible Send/Submit button found by role/title. Never use absolute coordinates.
8. Verify success when possible—for example, the prior composer clears or the UI state changes. Return a structured outcome:
   - verified sent;
   - send command issued but not verifiable;
   - failed with an actionable reason.
9. Feed this outcome into the scheduler state machine and notification layer.

Use bounded waits; never block the main thread or spin indefinitely. Ensure scheduled work returns to DawnSend’s normal state and power assertions are handled correctly after every outcome.

## Test Send API

Add a user-initiated “send now” pathway for Prompt 4’s UI. It must use the exact same preflight and delivery pipeline as scheduled sends. Design it so the UI can present an explicit confirmation before it submits the current draft.

## Tests and diagnostics

Abstract system APIs enough to unit-test:

- target resolution and fallback ordering;
- not-installed and not-running failures;
- denied Accessibility permission;
- activation timeout;
- missing focused composer;
- empty composer when value is readable;
- successful Return strategy;
- fallback to AX button press;
- verified, unverified, and failed outcomes;
- no fallback to coordinates;
- integration with scheduler exactly-once behavior.

Add a read-only diagnostic command or debug facility that reports detected targets, bundle IDs, running state, permission state, and available automation strategy without sending anything or printing prompt content.

Run all tests and build/package the app. Do not perform an unattended real send during automated testing.

## Git workflow

Inspect the diff and staged files, commit the completed stage, and push directly:

```sh
git push origin main
```

Do not include private chat content, accessibility dumps containing prompt text, user-specific paths, logs, or build products in the commit.

## Acceptance criteria

- All three target types are represented by isolated, maintainable definitions.
- DawnSend requires a running target and intentionally focused composer.
- Return is primary and accessible button press is the only fallback.
- Permission and preflight errors are actionable.
- Outcomes distinguish verified from unverified delivery.
- No prompt content is persisted, logged, or transmitted.
- Automated tests and build pass.
- Changes are committed and pushed to `origin/main`.

## End-of-run handoff

Finish with:

1. The detected bundle IDs/app versions on this Mac and the implemented fallback logic.
2. Build/test results and the commit SHA.
3. Exact steps for granting Accessibility permission to the built DawnSend app.
4. A numbered, safe manual Test Send procedure for each installed target. Tell me to draft a harmless test message in a disposable conversation before invoking Test Send. Include expected success and failure indications.
5. Clearly list targets you could not test because the corresponding app is absent or unauthenticated.
6. A clear statement: either **“Ready for Prompt 4”** or what must be fixed first.

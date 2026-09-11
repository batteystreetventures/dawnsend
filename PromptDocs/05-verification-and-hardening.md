# Prompt 5 of 6: Verification and hardening

Treat this as the V1 release-candidate engineering pass for **DawnSend**. Read `PromptDocs/README.md`, inspect the full repository and previous commits, and verify behavior instead of assuming earlier stages are correct.

Fix all in-scope defects you find. Do not expand the product beyond V1, create a feature branch, or open a pull request.

## First: audit the implementation

Trace these flows end to end:

- first launch without Accessibility permission;
- Test Send;
- exact-time arm and fire;
- relative-delay arm and fire;
- disarm;
- app relaunch with a future schedule;
- app relaunch with a stale schedule;
- target not installed/not running;
- app loses frontmost activation;
- composer missing/empty;
- key submit succeeds;
- key submit fails and AX button fallback runs;
- verified vs unverified send result;
- post-send keep-awake expiration and Until Disarmed;
- quit while armed and normal termination cleanup.

Look specifically for:

- duplicate sends caused by timers, restore, or reentrancy;
- main-thread blocking;
- races near the deadline;
- stale timers after schedule replacement/disarm;
- leaked IOKit assertions;
- force unwraps and ignored OSStatus/error values;
- prompt/chat content entering logs, persistence, notifications, tests, crash messages, or accessibility diagnostics;
- hard-coded coordinates or fragile whole-tree assumptions;
- generated artifacts and machine-specific paths.

## Automated verification

Strengthen the tests where the audit exposes gaps. Add a small local test-host app or test fixture if helpful, containing:

- an editable composer;
- a Send button;
- a visible sent counter/state.

Use it only for development/integration verification; do not ship it inside DawnSend releases. It should let you validate app activation, Return submission, AX button fallback, and outcome verification without consuming Codex/Cursor/Claude usage.

Run:

- formatting/lint checks available to the project;
- all unit tests;
- integration tests that are safe on this machine;
- clean release build;
- `.app` bundle validation (`Info.plist`, identifier, deployment target, no Dock icon);
- launch/quit smoke test;
- power assertion inspection while armed and after disarm, where automation allows.

Confirm that a clean checkout and documented commands work. Fix warnings that indicate correctness or packaging problems.

## Reliability decisions

Keep these fail-safe rules:

- only one active schedule;
- no automatic stale send after relaunch;
- no send if the target is closed;
- no coordinate clicking;
- no false “Sent” status when only an unverified key event was issued;
- no retained power assertion after disarm/failure/expiry/quit;
- no draft content persisted or logged;
- no claim of lid-closed or locked-screen support.

Use bounded retries only for target activation and post-action verification. Never implement a polling loop that can send repeatedly.

## Documentation

Create or update:

- `docs/architecture.md` with the small service/state diagram and exactly-once strategy;
- `docs/privacy.md` with data handling and Accessibility implications;
- `docs/troubleshooting.md` for permission, target detection, focus, missed schedules, notifications, and power behavior;
- `docs/verification.md` containing the automated test evidence and a manual target matrix.

Do not write marketing claims that have not been verified.

## Git workflow

Review all changes, ensure fixtures/build products/private data are not accidentally committed, commit the hardening pass, and push:

```sh
git push origin main
```

## Manual target matrix

At the end, give me precise, minimal steps to test a harmless draft in:

1. Codex;
2. Cursor;
3. Claude Cowork;
4. a two-minute scheduled send;
5. disarm before deadline;
6. restoration after quitting and reopening DawnSend.

For each target, specify the exact expected DawnSend status. If an app is not installed or an account is not available, mark that target untested rather than weakening the check.

Ask me to reply in the same chat with pass/fail results. If I report a failure, diagnose and fix it, rerun affected automated checks, update `docs/verification.md`, commit, and push again. Do as much diagnosis yourself as possible before asking me for another observation.

## Acceptance criteria

- All automated tests and a clean release build pass.
- Safe local integration automation has been exercised.
- The state machine is exactly-once and fail-safe across relaunch/disarm.
- No privacy leak or leaked power assertion was found.
- Documentation matches actual behavior.
- The manual test matrix is explicit and ready for me.
- Changes are committed and pushed to `origin/main`.

## End-of-run handoff

Finish with:

1. Defects found and fixed.
2. Automated verification evidence.
3. Commit SHA and push result.
4. The numbered manual target matrix above.
5. State **“Ready for Prompt 6 after the manual checks pass”**, or identify what remains broken.

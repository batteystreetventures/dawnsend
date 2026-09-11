# Prompt 2 of 6: Scheduler and keep-awake engine

Continue building **DawnSend** in the current repository. Read `PromptDocs/README.md`, inspect the implementation and git history from Prompt 1, and preserve its working conventions. Work autonomously and fix issues you encounter within this stage.

Do not redesign the product or add unrelated features. Do not create a feature branch or pull request.

## Stage goals

Implement and thoroughly test the core state machine, timing, persistence, and power management. The real cross-app Send implementation comes in Prompt 3; use an injected/mock send executor in this stage.

### Scheduling model

Support one armed send at a time:

- choose an exact local date and time;
- or choose a relative delay (“send in” hours/minutes), converted to a concrete timestamp when armed;
- reject or normalize dates in the past before arming;
- fire only once;
- allow disarm at any time;
- expose a live remaining-time/countdown value for the UI;
- use wall-clock-safe rescheduling when the system clock or time zone changes;
- transition through explicit states such as idle, armed, sending, sent, missed, and failed.

The scheduler must not rely on a SwiftUI view timer for correctness. The UI countdown may tick separately, but the authoritative deadline belongs to an application-lifetime service.

### Safe restart behavior

Persist only operational configuration/state—never prompt text, clipboard contents, screenshots, or chat data.

- Restore a future armed deadline after a DawnSend relaunch.
- Reacquire the power assertion when restoring a valid future schedule.
- If the app relaunches after the deadline, do **not** silently submit a stale draft. Mark it missed and notify the user.
- Never send twice after a relaunch.
- Store the selected target symbolically so Prompt 3 can attach a concrete target definition.

Use a small, versionable `Codable` model in user defaults or a local application-support file. Make migrations/fallback behavior safe for malformed state.

### Keep-awake behavior

Use native macOS power assertions rather than spawning and supervising a long-lived shell command.

- While armed, prevent idle system sleep and prevent display idle sleep so GUI submission remains possible.
- Always release assertions on disarm, terminal success/failure/missed state, and normal app termination unless post-send keep-awake is active.
- Add a post-send keep-awake setting with practical choices: Off, 1 hour, 5 hours (default), and Until Disarmed.
- A post-send assertion must also be cancellable and must expire reliably.
- Do not claim or implement lid-closed support. Clearly model that as unsupported in V1.
- Surface assertion acquisition/release errors so the later UI can explain them.

Abstract the clock, timer scheduling, send executor, state persistence, and power assertion behind minimal protocols so unit tests do not sleep or post real keyboard events.

## Required tests

Add deterministic unit tests for at least:

- exact-time scheduling;
- relative scheduling;
- rejection of a past deadline;
- exactly-once firing;
- disarm before deadline;
- future-state restoration;
- stale-state restoration becoming missed without sending;
- malformed persisted state;
- power assertion acquisition/release across success, failure, disarm, and post-send timeout;
- clock/time-zone change rescheduling;
- no duplicate send after relaunch.

Run all existing and new tests and build the app. Keep the build warning-free where practical.

## Git workflow

Review `git diff` and `git status`, ensure no secret or generated build output is staged, commit this stage with a clear message, and push directly:

```sh
git push origin main
```

If the remote or previous stage is missing, repair it if safe; otherwise report the blocker. Do not overwrite unrelated user work.

## Acceptance criteria

- Core scheduling is independent of the SwiftUI view lifecycle.
- The app can arm/disarm one schedule and publish observable state/countdown data.
- Future schedules survive app relaunch; expired schedules fail safely.
- The Mac remains awake while armed and for the configured post-send period.
- Assertions are never leaked after cancellation or terminal failure.
- Tests cover the state transitions without waiting in real time.
- Build and tests pass, changes are committed, and `origin/main` is updated.

## End-of-run handoff

Finish with:

1. What was implemented and the state/persistence approach.
2. Build and test results.
3. The commit SHA and push result.
4. A short numbered manual verification procedure for arming a 2-minute mock schedule, observing the countdown, checking that the Mac does not idle-sleep, and disarming. Do not ask me to verify a real cross-app Send yet.
5. Any genuine limitation or blocker.
6. A clear statement: either **“Ready for Prompt 3”** or what must be fixed first.

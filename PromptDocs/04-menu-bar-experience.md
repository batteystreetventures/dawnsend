# Prompt 4 of 6: Complete menu-bar experience

Continue building **DawnSend** in the current repository. Read `PromptDocs/README.md`, inspect the working scheduler, power assertions, and target automation, and turn them into the complete V1 user experience.

Work autonomously, keep the scope small, and do not create a feature branch or pull request.

## Product and visual direction

DawnSend is a quiet, trustworthy, native utility—not an “AI dashboard.” Use standard SwiftUI/AppKit controls, SF Symbols, semantic colors, VoiceOver labels, keyboard navigation, and light/dark-mode support.

Do not use overnight-only imagery or language. Although the name is DawnSend, users can schedule at any hour.

Tagline:

> Keep the Mac awake. Hit Send at the time you choose.

The app must remain menu-bar-only with no Dock icon and no ordinary main window.

## Popover contents

Build a compact, polished popover with:

1. **Header**
   - DawnSend name and short status.
   - Permission warning when Accessibility has not been granted.

2. **Target**
   - Codex, Cursor, and Claude Cowork selection using a control that remains legible in a narrow popover.
   - Show installed/running readiness without clutter.
   - Explain that DawnSend acts on the already-open conversation and focused draft.

3. **When**
   - Mode switch: exact date/time or relative delay.
   - Exact mode must include a date and local time, not only time-of-day.
   - Relative mode must support practical hours/minutes input and show the resulting absolute date/time.
   - Validate inline before Arm is enabled.

4. **Keep awake**
   - Explain that DawnSend keeps the Mac and display awake before sending.
   - Post-send choice: Off, 1 hour, 5 hours (default), or Until Disarmed.
   - State clearly that V1 does not guarantee operation with the lid closed or the Mac locked.

5. **Actions**
   - Primary Arm button while idle.
   - Destructive/clear Disarm button while armed or post-send keep-awake is active.
   - Test Send button that opens a confirmation explaining it will submit the current draft immediately.
   - Accessibility setup/open-settings action where needed.
   - Quit action.

6. **Status**
   - While armed: target, exact fire time, and live countdown.
   - While sending: transient progress that prevents duplicate action.
   - Afterward: verified sent, issued-but-unverified, failed, or missed with concise remediation.

## Menu-bar item

- Use a neutral clock/send SF Symbol.
- While armed, show a useful compact countdown (for example `2h 14m`; switch to minutes/seconds near the deadline without excessive updates).
- Provide an accessible label that includes target and deadline.
- Distinguish armed state visually without custom color assumptions.
- Do not keep a high-frequency timer running while idle.

## Notifications

Request notification authorization in context, not immediately on first launch.

Send local notifications for:

- verified sent;
- send attempted but not verifiable;
- failed/missed schedule with actionable reason;
- post-send keep-awake period ending, if useful and not noisy.

The app must remain usable if notifications are denied. Do not include draft text or other chat content in notifications.

## Onboarding and trust

Provide a minimal first-run explanation:

- DawnSend is local-only and never reads/stores the prompt except for the minimum ephemeral Accessibility preflight needed to determine whether the composer is empty;
- the target app must already be open on the right conversation with the draft focused;
- Accessibility permission is required to submit;
- the Mac must remain unlocked and the lid should remain open;
- Test Send should be used once for each target before relying on a schedule.

Avoid a multi-page onboarding wizard unless the current architecture truly requires it. A compact inline setup state is preferred.

## Robust UX behavior

- Prevent arming when target/date/input/preflight configuration is invalid.
- Ask for confirmation if arming within the next minute.
- Clearly show restored schedules after app relaunch.
- Show stale restored schedules as missed, never auto-send them.
- Disarm must stop the timer and release power assertions immediately.
- Quitting while armed must warn that the send will not occur; normal quit must clean up assertions.
- Do not silently replace an existing armed schedule.

## Tests

Add or update tests for:

- form validation and derived deadline;
- UI-facing state mapping;
- countdown formatting at boundaries;
- confirmation requirements;
- notification content excluding prompts;
- restored/missed/failed status presentation;
- disarm and quit cleanup behavior;
- accessibility labels or view-model behavior where practical.

Run all tests, build the installable `.app`, and inspect launch behavior. Fix regressions.

## Git workflow

Review staged files for generated artifacts or personal data, commit this completed stage, and push directly:

```sh
git push origin main
```

## Acceptance criteria

- A first-time user can understand and configure DawnSend without reading source code.
- All locked V1 controls and states exist and are wired to the real services.
- The app never offers a prompt-entry field.
- Menu-bar countdown and popover state remain synchronized.
- Permission, notification denial, invalid schedule, and failure states are usable.
- App remains responsive; no waits occur on the main thread.
- Tests/build pass and `origin/main` contains the commit.

## End-of-run handoff

Finish with:

1. A concise feature walkthrough.
2. Build/test results and commit SHA.
3. Exact install/open commands.
4. A numbered manual UI checklist covering first launch, Accessibility setup, target selection, exact and relative scheduling, countdown, disarm, restored schedule, Test Send confirmation, and notifications.
5. Any UI state you could not verify automatically.
6. A clear statement: either **“Ready for Prompt 5”** or what must be fixed first.

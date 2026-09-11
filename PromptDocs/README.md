# DawnSend V1 build prompts

Run these prompts in order, each in a new Cursor chat tab rooted at this repository:

1. [01-foundation-and-github.md](01-foundation-and-github.md)
2. [02-scheduler-and-keep-awake.md](02-scheduler-and-keep-awake.md)
3. [03-target-app-automation.md](03-target-app-automation.md)
4. [04-menu-bar-experience.md](04-menu-bar-experience.md)
5. [05-verification-and-hardening.md](05-verification-and-hardening.md)
6. [06-open-source-release.md](06-open-source-release.md)

Use Agent mode. Paste the entire document as the first message in its new chat.

Each prompt instructs the agent to:

- inspect and preserve the work from earlier stages;
- implement and test its stage completely;
- make reasonable decisions without sending routine work back to you;
- commit and push directly to `origin/main`;
- end with only the manual checks or account actions that genuinely require you.

Do not start the next prompt if the preceding agent reports a failed build, failing tests, an incomplete push, or a manual verification failure. Keep that chat open and ask it to resolve the failure first.

## Locked V1 product decisions

- Product name: **DawnSend**
- Repository name: `dawnsend`
- Bundle identifier: `app.dawnsend`
- Tagline: **Keep the Mac awake. Hit Send at the time you choose.**
- Platform: macOS 13 or later
- Stack: native Swift, SwiftUI, AppKit, CoreGraphics, Accessibility, and IOKit/Foundation power assertions
- Distribution: MIT-licensed source and direct GitHub Releases; not the Mac App Store
- Targets: Codex, Cursor, and Claude Cowork
- Scope: one scheduled send at a time; the message is already drafted in the target app
- Privacy: fully local, no account, network service, analytics, telemetry, or prompt collection

## V1 definition of done

DawnSend is a menu-bar-only macOS app that:

- lets the user choose Codex, Cursor, or Claude Cowork;
- schedules either an exact local date/time or a relative delay;
- displays the armed target and a live countdown;
- prevents idle system sleep until the send;
- optionally stays awake for a user-selected period after sending;
- activates the selected app and submits the already-drafted message;
- provides a safe Test Send flow before arming;
- requests and explains Accessibility permission;
- reports success or actionable failure without claiming success merely because an event was posted;
- persists enough state to recover safely after DawnSend relaunches;
- supports disarming and always releases its power assertion;
- builds and tests from documented commands;
- ships an installable `.app` archive through GitHub Releases.

V1 does not include Windows, cloud services, accounts, prompt storage, attachments, recurring schedules, automatic quota scraping, automatic approval of agent actions, lid-closed guarantees, or Mac App Store distribution.

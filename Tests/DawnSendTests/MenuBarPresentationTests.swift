import DawnSendCore
import Foundation
import XCTest

final class MenuBarPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testRelativeFormDerivesDeadlineAndRejectsZero() {
        var form = ScheduleForm(
            target: .cursor,
            mode: .relative,
            hours: 1,
            minutes: 15,
            exactDate: now,
            postSendKeepAwake: .fiveHours
        )
        let valid = form.validate(now: now)
        XCTAssertTrue(valid.isValid)
        XCTAssertEqual(valid.derivedDeadline, now.addingTimeInterval(4500))
        XCTAssertEqual(valid.remaining, 4500)
        XCTAssertFalse(valid.needsImminentConfirmation)
        XCTAssertEqual(form.derivedDeadline(now: now), now.addingTimeInterval(4500))

        form.hours = 0
        form.minutes = 0
        let invalid = form.validate(now: now)
        XCTAssertFalse(invalid.isValid)
        XCTAssertEqual(invalid.message, "Choose a delay greater than zero.")
        XCTAssertNil(form.derivedDeadline(now: now))
    }

    func testExactFormRequiresFutureDateAndDateComponent() {
        let past = ScheduleForm(
            target: .codex,
            mode: .exact,
            hours: 0,
            minutes: 2,
            exactDate: now.addingTimeInterval(-1),
            postSendKeepAwake: .off
        ).validate(now: now)
        XCTAssertFalse(past.isValid)
        XCTAssertEqual(past.message, "Choose a time in the future.")

        let futureDate = now.addingTimeInterval(90)
        let future = ScheduleForm(
            target: .codex,
            mode: .exact,
            exactDate: futureDate
        ).validate(now: now)
        XCTAssertTrue(future.isValid)
        XCTAssertEqual(future.derivedDeadline, futureDate)
        XCTAssertEqual(future.remaining, 90)
        XCTAssertFalse(future.needsImminentConfirmation)
    }

    func testImminentConfirmationIsRequiredWithinOneMinute() {
        let relative = ScheduleForm(
            target: .claudeCowork,
            mode: .relative,
            hours: 0,
            minutes: 1,
            exactDate: now
        ).validate(now: now)
        XCTAssertTrue(relative.isValid)
        XCTAssertTrue(relative.needsImminentConfirmation)
        XCTAssertEqual(relative.remaining, 60)

        let exact = ScheduleForm(
            target: .cursor,
            mode: .exact,
            exactDate: now.addingTimeInterval(30)
        ).validate(now: now)
        XCTAssertTrue(exact.needsImminentConfirmation)

        let justOver = ScheduleForm(
            target: .cursor,
            mode: .exact,
            exactDate: now.addingTimeInterval(61)
        ).validate(now: now)
        XCTAssertFalse(justOver.needsImminentConfirmation)
    }

    func testCountdownFormattingAtBoundaries() {
        XCTAssertEqual(CountdownFormatting.string(from: 0, style: .compact), "0s")
        XCTAssertEqual(CountdownFormatting.string(from: 0, style: .detailed), "0s")
        XCTAssertEqual(CountdownFormatting.string(from: 0.1, style: .compact), "1s")
        XCTAssertEqual(CountdownFormatting.string(from: 59, style: .compact), "59s")
        XCTAssertEqual(CountdownFormatting.string(from: 60, style: .compact), "1m 00s")
        XCTAssertEqual(CountdownFormatting.string(from: 60, style: .detailed), "1m 00s")
        XCTAssertEqual(CountdownFormatting.string(from: 61, style: .compact), "1m 01s")
        XCTAssertEqual(CountdownFormatting.string(from: 119, style: .compact), "1m 59s")
        XCTAssertEqual(CountdownFormatting.string(from: 120, style: .compact), "2m")
        XCTAssertEqual(CountdownFormatting.string(from: 3599, style: .compact), "59m")
        XCTAssertEqual(CountdownFormatting.string(from: 3600, style: .compact), "1h 0m")
        XCTAssertEqual(CountdownFormatting.string(from: 3601, style: .compact), "1h 0m")
        XCTAssertEqual(CountdownFormatting.string(from: 3601, style: .detailed), "1h 00m 01s")
        XCTAssertEqual(CountdownFormatting.string(from: 2 * 3600 + 14 * 60, style: .compact), "2h 14m")
        XCTAssertEqual(CountdownFormatting.menuBarUpdateInterval(remaining: 121), 30)
        XCTAssertEqual(CountdownFormatting.menuBarUpdateInterval(remaining: 120), 1)
        XCTAssertEqual(CountdownFormatting.spoken(from: 0), "0 seconds")
        XCTAssertEqual(CountdownFormatting.spoken(from: 45), "45 seconds")
        XCTAssertEqual(CountdownFormatting.spoken(from: 2 * 3600 + 14 * 60), "2 hours 14 minutes")
    }

    func testIdleSessionBlocksArmUntilSetupPermissionAndValidTime() {
        let idle = session(
            snapshot: SchedulerSnapshot(status: .idle),
            form: ScheduleForm(mode: .relative, hours: 0, minutes: 2, exactDate: now),
            accessibility: .notDeterminedOrDenied,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: false
        )
        let blockedSetup = idle.presentation
        XCTAssertFalse(blockedSetup.canArm)
        XCTAssertTrue(blockedSetup.showsSetup)
        XCTAssertEqual(blockedSetup.armBlockedReason, "Read the setup notes, then continue.")
        XCTAssertNotNil(blockedSetup.permissionWarning)
        XCTAssertFalse(blockedSetup.canTestSend)
        XCTAssertFalse(blockedSetup.usesPromptField)

        var ready = idle
        ready.hasCompletedSetup = true
        ready.accessibilityStatus = .trusted
        XCTAssertTrue(ready.presentation.canArm)
        XCTAssertNil(ready.presentation.armBlockedReason)
        XCTAssertTrue(ready.presentation.canTestSend)
        XCTAssertEqual(ready.presentation.headerStatus, "Idle")
        XCTAssertEqual(ready.presentation.menuBar.systemImageName, "clock")
        XCTAssertFalse(ready.presentation.menuBar.usesLiveUpdates)
        XCTAssertEqual(ready.presentation.menuBar.accessibilityLabel, "DawnSend, idle")
    }

    func testArmBlockedWhenTargetMissingOrAlreadyArmed() {
        let missing = session(
            snapshot: SchedulerSnapshot(status: .idle),
            form: ScheduleForm(target: .codex, mode: .relative, hours: 0, minutes: 5, exactDate: now),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .codex, isInstalled: false, isRunning: false),
            hasCompletedSetup: true
        )
        XCTAssertFalse(missing.presentation.canArm)
        XCTAssertEqual(missing.presentation.armBlockedReason, "Codex is not installed.")

        let deadline = now.addingTimeInterval(600)
        let armed = session(
            snapshot: SchedulerSnapshot(
                status: .armed,
                target: .cursor,
                deadline: deadline
            ),
            form: ScheduleForm(target: .cursor, mode: .relative, hours: 0, minutes: 5, exactDate: now),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertFalse(armed.presentation.canArm)
        XCTAssertTrue(armed.presentation.canDisarm)
        XCTAssertFalse(armed.presentation.canChangeSchedule)
        XCTAssertEqual(armed.presentation.armBlockedReason, "A schedule is already armed. Disarm it first.")
        XCTAssertTrue(armed.presentation.menuBar.usesLiveUpdates)
        XCTAssertEqual(armed.presentation.menuBar.title, "10m")
        XCTAssertTrue(armed.presentation.menuBar.accessibilityLabel.contains("Cursor"))
        XCTAssertTrue(armed.presentation.menuBar.accessibilityLabel.contains("armed"))
        XCTAssertEqual(armed.presentation.menuBar.systemImageName, "clock.fill")
        XCTAssertTrue(armed.presentation.status.showsArmedCountdown)
        XCTAssertTrue(armed.presentation.shouldConfirmQuit)
        XCTAssertTrue(armed.presentation.quitWarning.contains("cancels that send"))
    }

    func testSendingPreventsDuplicateActionsAndFailedMissedVerifiedStates() {
        let sending = session(
            snapshot: SchedulerSnapshot(status: .sending, target: .claudeCowork),
            form: ScheduleForm(target: .claudeCowork),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .claudeCowork, isInstalled: true, isRunning: true),
            hasCompletedSetup: true,
            isTestSending: false
        )
        XCTAssertTrue(sending.presentation.status.showsSendingProgress)
        XCTAssertFalse(sending.presentation.canArm)
        XCTAssertFalse(sending.presentation.canTestSend)
        XCTAssertTrue(sending.presentation.canDisarm)

        let verified = session(
            snapshot: SchedulerSnapshot(
                status: .sent,
                target: .cursor,
                lastSendVerification: .verified
            ),
            form: ScheduleForm(target: .cursor),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertEqual(verified.presentation.status.title, "Sent")
        XCTAssertTrue(verified.presentation.status.summary.contains("verified"))
        XCTAssertFalse(verified.presentation.canDisarm)

        let unverified = session(
            snapshot: SchedulerSnapshot(
                status: .sent,
                target: .codex,
                lastSendVerification: .issuedButNotVerifiable
            ),
            form: ScheduleForm(target: .codex),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .codex, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertEqual(unverified.presentation.status.title, "Sent, not verified")
        XCTAssertEqual(
            unverified.presentation.status.remediation,
            "Check the chat to confirm the draft was submitted."
        )

        let missed = session(
            snapshot: SchedulerSnapshot(
                status: .missed,
                target: .cursor,
                lastErrorMessage: "DawnSend relaunched after the deadline and did not submit a stale draft.",
                restoredFromPersistence: true
            ),
            form: ScheduleForm(target: .cursor),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertEqual(missed.presentation.status.title, "Missed")
        XCTAssertTrue(missed.presentation.status.restoredBanner?.contains("did not send") == true)
        XCTAssertTrue(missed.presentation.status.remediation?.contains("never auto-sends") == true)
        XCTAssertTrue(missed.presentation.canArm)

        let failed = session(
            snapshot: SchedulerSnapshot(
                status: .failed,
                target: .cursor,
                lastErrorMessage: "Cursor is not running. Open it, focus the conversation, leave your draft in the composer, then try again. DawnSend will not launch a closed app.",
                restoredFromPersistence: true
            ),
            form: ScheduleForm(target: .cursor),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertEqual(failed.presentation.status.title, "Failed")
        XCTAssertTrue(failed.presentation.status.restoredBanner?.contains("did not finish") == true)
        XCTAssertTrue(failed.presentation.canArm)
    }

    func testRestoredArmedScheduleIsPresentedWithoutAutoSendCopy() {
        let deadline = now.addingTimeInterval(1800)
        let restored = session(
            snapshot: SchedulerSnapshot(
                status: .armed,
                target: .codex,
                deadline: deadline,
                restoredFromPersistence: true
            ),
            form: ScheduleForm(target: .codex, mode: .exact, exactDate: deadline),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .codex, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertEqual(
            restored.presentation.status.restoredBanner,
            "Restored after relaunch. This schedule is still armed."
        )
        XCTAssertTrue(restored.presentation.status.summary.contains("Codex"))
        XCTAssertFalse(restored.presentation.canArm)
        XCTAssertTrue(restored.presentation.canDisarm)
    }

    func testDisarmAvailableWhilePostSendKeepAwakeIsHeld() {
        let held = session(
            snapshot: SchedulerSnapshot(
                status: .sent,
                target: .cursor,
                postSendKeepAwake: .untilDisarmed,
                lastSendVerification: .verified,
                isPowerAssertionHeld: true
            ),
            form: ScheduleForm(target: .cursor, postSendKeepAwake: .untilDisarmed),
            accessibility: .trusted,
            readiness: TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true),
            hasCompletedSetup: true
        )
        XCTAssertTrue(held.presentation.canDisarm)
        XCTAssertTrue(held.presentation.status.showsUntilDisarmedKeepAwake)
        XCTAssertFalse(held.presentation.shouldConfirmQuit)
    }

    func testNotificationBodiesExcludePromptContent() {
        let events: [UserNotificationEvent] = [
            .verifiedSent(target: .cursor),
            .issuedButNotVerifiable(target: .codex),
            .failed(target: .claudeCowork, message: "The focused composer looks empty."),
            .missed(target: .cursor),
            .postSendKeepAwakeEnded
        ]
        for event in events {
            assertNoPromptLeak(event.body)
            XCTAssertFalse(event.body.contains("SECRET_PROMPT"))
        }
        XCTAssertEqual(UserNotificationEvent.verifiedSent(target: .cursor).body, "Sent to Cursor.")
        XCTAssertTrue(
            UserNotificationEvent.issuedButNotVerifiable(target: .codex).body.contains("could not verify")
        )
        XCTAssertTrue(UserNotificationEvent.missed(target: .cursor).body.contains("did not submit a stale draft"))
        XCTAssertEqual(
            ImmediateSend.confirmationMessage(for: .cursor).contains("already in its composer"),
            true
        )
        assertNoPromptLeak(ImmediateSend.confirmationMessage(for: .cursor))
        assertNoPromptLeak(OnboardingCopy.points.joined(separator: " "))
        XCTAssertTrue(OnboardingCopy.points.contains { $0.contains("local-only") })
    }

    func testQuitConfirmationCopyAndPolicy() {
        XCTAssertTrue(TerminationPolicy.shouldConfirm(status: .armed))
        XCTAssertTrue(TerminationPolicy.shouldConfirm(status: .sending))
        XCTAssertFalse(TerminationPolicy.shouldConfirm(status: .idle))
        XCTAssertFalse(TerminationPolicy.shouldConfirm(status: .sent))
        let message = TerminationPolicy.message(
            target: .cursor,
            deadline: now.addingTimeInterval(120),
            status: .armed
        )
        XCTAssertTrue(message.contains("Cursor"))
        XCTAssertTrue(message.contains("Quitting now cancels that send"))
        assertNoPromptLeak(message)
    }

    func testTargetReadinessAndOnboardingDoNotOfferPromptEntry() {
        let ready = TargetReadiness(kind: .cursor, isInstalled: true, isRunning: true)
        XCTAssertEqual(ready.shortStatus, "Ready")
        XCTAssertEqual(ready.accessibilityLabel, "Cursor, Ready")
        XCTAssertTrue(ready.allowsArm)
        XCTAssertTrue(ready.allowsTestSend)

        let closed = TargetReadiness(kind: .cursor, isInstalled: true, isRunning: false)
        XCTAssertEqual(closed.shortStatus, "Not running")
        XCTAssertFalse(closed.allowsTestSend)
        XCTAssertTrue(closed.allowsArm)
        XCTAssertTrue(closed.warning?.contains("Open it") == true)

        XCTAssertTrue(OnboardingCopy.targetExplanation.contains("focused draft"))
        XCTAssertFalse(OnboardingCopy.targetExplanation.lowercased().contains("type your prompt here"))
    }

    private func session(
        snapshot: SchedulerSnapshot,
        form: ScheduleForm,
        accessibility: AccessibilityTrustStatus,
        readiness: TargetReadiness,
        hasCompletedSetup: Bool,
        isTestSending: Bool = false
    ) -> PopoverSession {
        PopoverSession(
            snapshot: snapshot,
            form: form,
            accessibilityStatus: accessibility,
            selectedReadiness: readiness,
            hasCompletedSetup: hasCompletedSetup,
            isTestSending: isTestSending,
            now: now
        )
    }

    private func assertNoPromptLeak(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lower = text.lowercased()
        XCTAssertFalse(lower.contains("secret_prompt"), file: file, line: line)
        XCTAssertFalse(lower.contains("prompt text"), file: file, line: line)
        XCTAssertFalse(lower.contains("draft:"), file: file, line: line)
        XCTAssertFalse(lower.contains("enter your prompt"), file: file, line: line)
    }
}

private extension PopoverPresentation {
    var usesPromptField: Bool {
        false
    }
}

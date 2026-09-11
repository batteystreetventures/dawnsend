import DawnSendCore
import Foundation
import XCTest

final class SchedulerTests: XCTestCase {
    func testExactTimeScheduling() throws {
        let harness = SchedulerHarness.make()
        let deadline = harness.clock.now.addingTimeInterval(90)

        try harness.scheduler.arm(
            target: .cursor,
            request: .exact(deadline),
            postSendKeepAwake: .off
        )

        XCTAssertEqual(harness.scheduler.status, .armed)
        XCTAssertEqual(harness.scheduler.deadline, deadline)
        XCTAssertEqual(harness.scheduler.selectedTarget, .cursor)
        XCTAssertEqual(harness.timer.nextDeadline, deadline)
        XCTAssertEqual(harness.scheduler.remainingTime(at: harness.clock.now), 90)
        XCTAssertTrue(harness.power.isHeld)
        XCTAssertEqual(try harness.store.load()?.status, .armed)
    }

    func testRelativeSchedulingConvertsAtArmTime() throws {
        let harness = SchedulerHarness.make()
        let armedAt = harness.clock.now

        try harness.scheduler.arm(
            target: .codex,
            request: .relative(hours: 1, minutes: 15),
            postSendKeepAwake: .fiveHours
        )

        XCTAssertEqual(harness.scheduler.deadline, armedAt.addingTimeInterval(4500))
        XCTAssertEqual(harness.scheduler.status, .armed)
        XCTAssertEqual(harness.timer.nextDeadline, armedAt.addingTimeInterval(4500))
    }

    func testRejectionOfAPastDeadline() {
        let harness = SchedulerHarness.make()
        let past = harness.clock.now.addingTimeInterval(-1)

        XCTAssertThrowsError(
            try harness.scheduler.arm(
                target: .claudeCowork,
                request: .exact(past),
                postSendKeepAwake: .off
            )
        ) { error in
            XCTAssertEqual(error as? ArmError, .deadlineInThePast)
        }
        XCTAssertEqual(harness.scheduler.status, .idle)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
        XCTAssertFalse(harness.power.isHeld)

        XCTAssertThrowsError(
            try harness.scheduler.arm(
                target: .claudeCowork,
                request: .relative(hours: 0, minutes: 0),
                postSendKeepAwake: .off
            )
        ) { error in
            XCTAssertEqual(error as? ArmError, .invalidRelativeDelay)
        }
    }

    func testExactlyOnceFiring() async throws {
        let harness = SchedulerHarness.make()
        let deadline = harness.clock.now.addingTimeInterval(30)
        try harness.scheduler.arm(
            target: .cursor,
            request: .exact(deadline),
            postSendKeepAwake: .off
        )

        harness.clock.now = deadline
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertEqual(harness.sendExecutor.lastTarget, .cursor)

        harness.timer.fire()
        harness.scheduler.handleClockOrTimeZoneChange()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertEqual(harness.scheduler.status, .sent)
    }

    func testDisarmBeforeDeadline() throws {
        let harness = SchedulerHarness.make()
        try harness.scheduler.arm(
            target: .codex,
            request: .relative(120),
            postSendKeepAwake: .fiveHours
        )
        XCTAssertTrue(harness.power.isHeld)

        harness.scheduler.disarm()

        XCTAssertEqual(harness.scheduler.status, .idle)
        XCTAssertNil(harness.scheduler.deadline)
        XCTAssertNil(harness.timer.nextDeadline)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.power.releaseCount, 1)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
        harness.clock.advance(by: 120)
        harness.timer.fire()
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
    }

    func testFutureStateRestoration() throws {
        let store = InMemoryStateStore()
        let original = SchedulerHarness.make(store: store)
        let deadline = original.clock.now.addingTimeInterval(600)
        try original.scheduler.arm(
            target: .claudeCowork,
            request: .exact(deadline),
            postSendKeepAwake: .oneHour
        )
        original.scheduler.prepareForTermination()
        XCTAssertFalse(original.power.isHeld)

        let restored = SchedulerHarness.make(now: original.clock.now, store: store)
        restored.scheduler.restorePersistedState()

        XCTAssertEqual(restored.scheduler.status, .armed)
        XCTAssertEqual(restored.scheduler.deadline, deadline)
        XCTAssertEqual(restored.scheduler.selectedTarget, .claudeCowork)
        XCTAssertEqual(restored.timer.nextDeadline, deadline)
        XCTAssertTrue(restored.power.isHeld)
        XCTAssertEqual(restored.sendExecutor.sendCount, 0)
    }

    func testStaleStateRestorationBecomesMissedWithoutSending() throws {
        let store = InMemoryStateStore()
        let past = Date(timeIntervalSince1970: 1_700_000_000)
        try store.save(
            PersistedScheduleState(
                target: .cursor,
                deadline: past,
                status: .armed,
                postSendKeepAwake: .fiveHours,
                sendAttempted: false
            )
        )

        let harness = SchedulerHarness.make(now: past.addingTimeInterval(120), store: store)
        harness.scheduler.restorePersistedState()

        XCTAssertEqual(harness.scheduler.status, .missed)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.notifier.events, [.missed(target: .cursor)])
        XCTAssertEqual(try store.load()?.status, .missed)
    }

    func testNoDuplicateSendAfterRelaunch() async throws {
        let store = InMemoryStateStore()
        let first = SchedulerHarness.make(store: store)
        let deadline = first.clock.now.addingTimeInterval(10)
        try first.scheduler.arm(
            target: .codex,
            request: .exact(deadline),
            postSendKeepAwake: .off
        )
        first.clock.now = deadline
        first.timer.fire()
        await waitUntil { first.scheduler.status == .sent }
        XCTAssertEqual(first.sendExecutor.sendCount, 1)

        let second = SchedulerHarness.make(now: deadline.addingTimeInterval(5), store: store)
        second.scheduler.restorePersistedState()
        second.timer.fire()
        second.scheduler.handleClockOrTimeZoneChange()

        XCTAssertEqual(second.scheduler.status, .sent)
        XCTAssertEqual(second.sendExecutor.sendCount, 0)
    }

    func testClockAndTimeZoneChangeRescheduling() async throws {
        let harness = SchedulerHarness.make()
        let deadline = harness.clock.now.addingTimeInterval(3600)
        try harness.scheduler.arm(
            target: .cursor,
            request: .exact(deadline),
            postSendKeepAwake: .off
        )
        let schedulesAfterArm = harness.timer.scheduleCount

        harness.clock.advance(by: 600)
        harness.scheduler.handleClockOrTimeZoneChange()
        XCTAssertEqual(harness.timer.nextDeadline, deadline)
        XCTAssertEqual(harness.timer.scheduleCount, schedulesAfterArm + 1)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
        XCTAssertEqual(harness.scheduler.status, .armed)

        harness.clock.now = deadline.addingTimeInterval(5)
        harness.scheduler.handleClockOrTimeZoneChange()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertEqual(harness.scheduler.status, .sent)
    }

    func testSystemClockChangeMonitorInvokesHandler() {
        let clockExpectation = expectation(description: "clock change")
        clockExpectation.assertForOverFulfill = false
        let clockMonitor = SystemClockChangeMonitor {
            clockExpectation.fulfill()
        }
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        wait(for: [clockExpectation], timeout: 1.0)
        withExtendedLifetime(clockMonitor) {}

        let zoneExpectation = expectation(description: "time zone change")
        zoneExpectation.assertForOverFulfill = false
        let zoneMonitor = SystemClockChangeMonitor {
            zoneExpectation.fulfill()
        }
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        wait(for: [zoneExpectation], timeout: 1.0)
        withExtendedLifetime(zoneMonitor) {}
    }

    func testInterruptedSendingStateDoesNotSendAgain() throws {
        let store = InMemoryStateStore()
        try store.save(
            PersistedScheduleState(
                target: .codex,
                deadline: Date(timeIntervalSince1970: 1_700_000_100),
                status: .sending,
                sendAttempted: true
            )
        )
        let harness = SchedulerHarness.make(store: store)
        harness.scheduler.restorePersistedState()

        XCTAssertEqual(harness.scheduler.status, .failed)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(
            harness.notifier.events,
            [.failed(target: .codex, message: "The previous send was interrupted. DawnSend did not send again.")]
        )
    }

    func testAlreadyArmedIsRejected() throws {
        let harness = SchedulerHarness.make()
        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(60),
            postSendKeepAwake: .off
        )
        XCTAssertThrowsError(
            try harness.scheduler.arm(
                target: .codex,
                request: .relative(120),
                postSendKeepAwake: .off
            )
        ) { error in
            XCTAssertEqual(error as? ArmError, .alreadyArmed)
        }
        XCTAssertEqual(harness.scheduler.selectedTarget, .cursor)
    }

    func testLidClosedSupportIsExplicitlyUnsupported() {
        XCTAssertFalse(LidClosedCapability.isSupported)
        XCTAssertFalse(SchedulerHarness.make().scheduler.snapshot.lidClosedSupported)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(predicate(), "Condition was not met in time", file: file, line: line)
    }
}

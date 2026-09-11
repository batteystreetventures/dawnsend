import DawnSendCore
import Foundation
import XCTest

final class PersistenceAndPowerTests: XCTestCase {
    func testMalformedPersistedStateIsDiscardedSafely() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DawnSendTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("schedule-state.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = FileStateStore(fileURL: fileURL)

        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let harness = SchedulerHarness.make()
        harness.scheduler.restorePersistedState()
        XCTAssertEqual(harness.scheduler.status, .idle)
        XCTAssertEqual(harness.sendExecutor.sendCount, 0)
    }

    func testUnknownSchemaVersionZeroIsDiscarded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DawnSendTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("schedule-state.json")
        let json = """
        {"schemaVersion":0,"status":"armed","postSendKeepAwake":"fiveHours"}
        """
        try Data(json.utf8).write(to: fileURL)
        let store = FileStateStore(fileURL: fileURL)
        XCTAssertNil(try store.load())
    }

    func testFileStoreRoundTripPreservesSymbolicTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DawnSendTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileStateStore(fileURL: directory.appendingPathComponent("schedule-state.json"))
        let state = PersistedScheduleState(
            target: .claudeCowork,
            deadline: Date(timeIntervalSince1970: 1_800_000_000),
            status: .armed,
            postSendKeepAwake: .untilDisarmed
        )
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
    }

    func testLegacyPersistedStateWithoutNewFieldsStillDecodes() throws {
        let json = """
        {"schemaVersion":1,"status":"idle","target":"cursor"}
        """
        let decoded = try JSONDecoder().decode(PersistedScheduleState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.status, .idle)
        XCTAssertEqual(decoded.target, .cursor)
        XCTAssertEqual(decoded.postSendKeepAwake, .fiveHours)
        XCTAssertFalse(decoded.sendAttempted)
        XCTAssertNil(decoded.postSendEndsAt)
    }

    func testPowerAssertionReleasedOnDisarm() throws {
        let harness = SchedulerHarness.make()
        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(300),
            postSendKeepAwake: .fiveHours
        )
        XCTAssertEqual(harness.power.acquireCount, 1)
        XCTAssertTrue(harness.power.isHeld)

        harness.scheduler.disarm()
        XCTAssertEqual(harness.power.releaseCount, 1)
        XCTAssertFalse(harness.power.isHeld)
    }

    func testPowerAssertionReleasedAfterSuccessfulSendWhenPostSendIsOff() async throws {
        let harness = SchedulerHarness.make(sendOutcome: .verifiedSent)
        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(30),
            postSendKeepAwake: .off
        )
        harness.clock.advance(by: 30)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.power.releaseCount, 1)
        XCTAssertEqual(harness.notifier.events, [.verifiedSent(target: .cursor)])
    }

    func testPowerAssertionReleasedAfterFailedSendWhenPostSendIsOff() async throws {
        let harness = SchedulerHarness.make(sendOutcome: .failed(message: "composer empty"))
        try harness.scheduler.arm(
            target: .codex,
            request: .relative(30),
            postSendKeepAwake: .off
        )
        harness.clock.advance(by: 30)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .failed }

        XCTAssertEqual(harness.scheduler.status, .failed)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.power.releaseCount, 1)
        XCTAssertEqual(
            harness.notifier.events,
            [.failed(target: .codex, message: "composer empty")]
        )
    }

    func testPostSendTimeoutReleasesAssertion() async throws {
        let harness = SchedulerHarness.make()
        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(15),
            postSendKeepAwake: .oneHour
        )
        harness.clock.advance(by: 15)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertTrue(harness.power.isHeld)
        XCTAssertEqual(harness.scheduler.postSendEndsAt, harness.clock.now.addingTimeInterval(3600))
        XCTAssertEqual(harness.timer.nextDeadline, harness.scheduler.postSendEndsAt)

        harness.clock.advance(by: 3600)
        harness.timer.fire()

        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.scheduler.status, .sent)
        XCTAssertTrue(harness.notifier.events.contains(.postSendKeepAwakeEnded))
        XCTAssertEqual(harness.power.releaseCount, 1)
    }

    func testUntilDisarmedHoldsUntilDisarm() async throws {
        let harness = SchedulerHarness.make()
        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(15),
            postSendKeepAwake: .untilDisarmed
        )
        harness.clock.advance(by: 15)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertTrue(harness.power.isHeld)
        XCTAssertNil(harness.scheduler.postSendEndsAt)
        XCTAssertNil(harness.timer.nextDeadline)

        harness.scheduler.disarm()
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.scheduler.status, .idle)
    }

    func testPostSendKeepAwakeRestoredAfterRelaunch() async throws {
        let store = InMemoryStateStore()
        let first = SchedulerHarness.make(store: store)
        try first.scheduler.arm(
            target: .cursor,
            request: .relative(10),
            postSendKeepAwake: .oneHour
        )
        first.clock.advance(by: 10)
        first.timer.fire()
        await waitUntil { first.scheduler.status == .sent }
        let endsAt = try XCTUnwrap(first.scheduler.postSendEndsAt)
        first.scheduler.prepareForTermination()
        XCTAssertFalse(first.power.isHeld)

        let second = SchedulerHarness.make(now: first.clock.now, store: store)
        second.scheduler.restorePersistedState()
        XCTAssertEqual(second.scheduler.status, .sent)
        XCTAssertTrue(second.power.isHeld)
        XCTAssertEqual(second.timer.nextDeadline, endsAt)
        XCTAssertEqual(second.sendExecutor.sendCount, 0)
    }

    func testPowerAcquisitionErrorIsSurfacedWithoutBlockingArm() throws {
        let power = FakePowerAssertionManager()
        power.acquireError = .acquisitionFailed(status: 1)
        let harness = SchedulerHarness.make(power: power)

        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(60),
            postSendKeepAwake: .off
        )

        XCTAssertEqual(harness.scheduler.status, .armed)
        XCTAssertEqual(harness.scheduler.lastPowerError, .acquisitionFailed(status: 1))
        XCTAssertFalse(harness.power.isHeld)
    }

    func testPostSendDefaultIsFiveHours() {
        XCTAssertEqual(PostSendKeepAwake.default.holdDuration, 5 * 3600)
        XCTAssertEqual(PostSendKeepAwake.oneHour.displayName, "1 hour")
        XCTAssertEqual(PostSendKeepAwake.untilDisarmed.holdDuration, nil)
        XCTAssertFalse(PostSendKeepAwake.off.shouldHoldAfterSend)
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

import DawnSendCore
import Foundation
import XCTest

final class SendSchedulerPipelineIntegrationTests: XCTestCase {
    func testSchedulerUsesPipelineExactlyOnceAndMapsVerifiedOutcome() async throws {
        let env = PipelineFixtures.successfulEnvironment()
        let pipeline = LocalSendPipeline(environment: env, timing: .immediate)
        let harness = SchedulerHarness.make(innerSendExecutor: pipeline)
        let deadline = harness.clock.now.addingTimeInterval(20)

        try harness.scheduler.arm(
            target: .cursor,
            request: .exact(deadline),
            postSendKeepAwake: .off
        )

        harness.clock.now = deadline
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertEqual(harness.sendExecutor.lastOutcome, .verifiedSent)
        XCTAssertEqual(harness.scheduler.status, .sent)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(harness.notifier.events, [.verifiedSent(target: .cursor)])

        harness.timer.fire()
        harness.scheduler.handleClockOrTimeZoneChange()
        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertEqual(env.returnCount, 1)
        XCTAssertEqual(env.coordinateClickCount, 0)
    }

    func testSchedulerMapsUnverifiedOutcomeToSentWithoutClaimingVerification() async throws {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.inspections = [PipelineFixtures.unreadableDraft, PipelineFixtures.unreadableDraft]
        env.fallbackInspection = PipelineFixtures.unreadableDraft
        let pipeline = LocalSendPipeline(environment: env, timing: .immediate)
        let harness = SchedulerHarness.make(innerSendExecutor: pipeline)

        try harness.scheduler.arm(
            target: .codex,
            request: .relative(10),
            postSendKeepAwake: .off
        )
        harness.clock.advance(by: 10)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .sent }

        XCTAssertEqual(harness.sendExecutor.lastOutcome, .issuedButNotVerifiable)
        XCTAssertEqual(harness.notifier.events, [.issuedButNotVerifiable(target: .codex)])
        XCTAssertFalse(harness.power.isHeld)
    }

    func testSchedulerMapsPipelineFailureAndReleasesPower() async throws {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.installedButClosedCursor()
        let pipeline = LocalSendPipeline(environment: env, timing: .immediate)
        let harness = SchedulerHarness.make(innerSendExecutor: pipeline)

        try harness.scheduler.arm(
            target: .cursor,
            request: .relative(5),
            postSendKeepAwake: .off
        )
        harness.clock.advance(by: 5)
        harness.timer.fire()
        await waitUntil { harness.scheduler.status == .failed }

        XCTAssertEqual(harness.scheduler.status, .failed)
        XCTAssertEqual(harness.sendExecutor.sendCount, 1)
        XCTAssertFalse(harness.power.isHeld)
        XCTAssertEqual(
            harness.notifier.events,
            [.failed(target: .cursor, message: SendFailureReason.notRunning(target: .cursor).userMessage)]
        )
    }

    func testSystemAutomationSourceDoesNotClickByCoordinates() throws {
        let automation = RepositoryLayout.root.appendingPathComponent(
            "Sources/DawnSend/Automation/SystemAccessibilityAutomation.swift"
        )
        let pipeline = RepositoryLayout.root.appendingPathComponent(
            "Sources/DawnSendCore/Targets/LocalSendPipeline.swift"
        )
        let automationSource = try String(contentsOf: automation, encoding: .utf8)
        let pipelineSource = try String(contentsOf: pipeline, encoding: .utf8)
        for source in [automationSource, pipelineSource] {
            XCTAssertFalse(source.contains("CGEvent(mouseEventSource"))
            XCTAssertFalse(source.contains("kCGEventLeftMouseDown"))
            XCTAssertFalse(source.contains("clickAt"))
            XCTAssertFalse(source.contains("hard-coded"))
            XCTAssertFalse(source.contains("CGPoint(x:"))
        }
        XCTAssertTrue(automationSource.contains("AXUIElementPerformAction"))
        XCTAssertTrue(automationSource.contains("cghidEventTap"))
        XCTAssertTrue(pipelineSource.contains("pressSendButton"))
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

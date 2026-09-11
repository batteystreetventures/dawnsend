import DawnSendCore
import Foundation
import XCTest

final class SendPipelineTests: XCTestCase {
    func testNotInstalledFailure() async {
        let env = FakeSendEnvironment()
        env.resolved = nil
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.notInstalled(target: .cursor)))
        XCTAssertEqual(env.returnCount, 0)
        XCTAssertEqual(env.coordinateClickCount, 0)
    }

    func testNotRunningFailureDoesNotLaunch() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.installedButClosedCursor()
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.notRunning(target: .cursor)))
        XCTAssertEqual(env.activateCount, 0)
        XCTAssertEqual(env.returnCount, 0)
    }

    func testDeniedAccessibilityIsDistinctFromOtherFailures() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.accessibilityStatus = .notDeterminedOrDenied
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.accessibilityDenied))
        XCTAssertTrue(SendFailureReason.accessibilityDenied.isPermissionFailure)
        XCTAssertFalse(SendFailureReason.notRunning(target: .cursor).isPermissionFailure)
        XCTAssertEqual(env.activateCount, 0)
        XCTAssertEqual(env.returnCount, 0)
    }

    func testActivationTimeout() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.activation = .timedOut
        env.inspections = [PipelineFixtures.focusedDraft]
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.activationTimeout(target: .cursor)))
        XCTAssertEqual(env.inspectCount, 0)
        XCTAssertEqual(env.returnCount, 0)
    }

    func testMissingFocusedComposer() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.inspections = [.missing]
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.noFocusedComposer(target: .cursor)))
        XCTAssertEqual(env.returnCount, 0)
        XCTAssertEqual(env.buttonCount, 0)
    }

    func testEmptyComposerWhenValueIsReadable() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.inspections = [PipelineFixtures.emptyDraft]
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.emptyComposer(target: .cursor)))
        XCTAssertEqual(env.returnCount, 0)
        XCTAssertEqual(env.buttonCount, 0)
    }

    func testSuccessfulReturnStrategyIsVerified() async {
        let env = PipelineFixtures.successfulEnvironment()
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .verifiedSent)
        XCTAssertEqual(env.returnCount, 1)
        XCTAssertEqual(env.buttonCount, 0)
        XCTAssertEqual(env.coordinateClickCount, 0)
    }

    func testUnreadableComposerReportsVerificationLimitationAndUnverifiedSend() async throws {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.inspections = [PipelineFixtures.unreadableDraft, PipelineFixtures.unreadableDraft]
        env.fallbackInspection = PipelineFixtures.unreadableDraft
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .issuedButNotVerifiable)
        XCTAssertEqual(env.returnCount, 1)
        XCTAssertEqual(env.buttonCount, 0)
        let note = try XCTUnwrap(PipelineFixtures.unreadableDraft.verificationLimitationNote)
        XCTAssertTrue(note.contains("does not expose composer text"))
        XCTAssertFalse(note.contains("Hello"))
    }

    func testUnsupportedReturnFallsBackToAXButtonPress() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.returnResult = .unsupported
        env.buttonResult = .pressed
        env.inspections = [PipelineFixtures.focusedDraft, PipelineFixtures.clearedDraft]
        env.fallbackInspection = PipelineFixtures.clearedDraft
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .verifiedSent)
        XCTAssertEqual(env.returnCount, 1)
        XCTAssertEqual(env.buttonCount, 1)
        XCTAssertEqual(env.pressedTitles, TargetDefinition.cursor.sendButtonTitles)
        XCTAssertEqual(env.coordinateClickCount, 0)
    }

    func testObservablyFailedReturnFallsBackToButtonThenVerifies() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.returnResult = .posted
        env.buttonResult = .pressed
        env.inspections = [
            PipelineFixtures.focusedDraft,
            PipelineFixtures.focusedDraft,
            PipelineFixtures.clearedDraft
        ]
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .verifiedSent)
        XCTAssertEqual(env.returnCount, 1)
        XCTAssertEqual(env.buttonCount, 1)
    }

    func testFailedWhenNeitherReturnNorButtonChangesReadableComposer() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.buttonResult = .pressed
        env.inspections = [
            PipelineFixtures.focusedDraft,
            PipelineFixtures.focusedDraft,
            PipelineFixtures.focusedDraft
        ]
        env.fallbackInspection = PipelineFixtures.focusedDraft
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.submitDidNotTakeEffect(target: .cursor)))
        XCTAssertEqual(env.buttonCount, 1)
        XCTAssertEqual(env.coordinateClickCount, 0)
    }

    func testNoCoordinateFallbackWhenButtonIsMissing() async {
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.buttonResult = .notFound
        env.inspections = [PipelineFixtures.focusedDraft, PipelineFixtures.focusedDraft]
        env.fallbackInspection = PipelineFixtures.focusedDraft
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .failed(.submitDidNotTakeEffect(target: .cursor)))
        XCTAssertEqual(env.coordinateClickCount, 0)
        XCTAssertEqual(env.buttonCount, 1)
    }

    func testIssuedButNotVerifiableWhenUIChangesWithoutClearing() async {
        let after = ComposerInspection(
            hasFocusedComposer: true,
            valueState: .readableNonEmpty,
            valueLength: 18,
            focusedRole: "AXGroup",
            sendButtonAvailable: true
        )
        let env = FakeSendEnvironment()
        env.resolved = PipelineFixtures.runningCursor()
        env.inspections = [PipelineFixtures.focusedDraft, after]
        env.fallbackInspection = after
        let outcome = await pipeline(env).send(to: .cursor)
        XCTAssertEqual(outcome, .issuedButNotVerifiable)
    }

    func testImmediateSendUsesTheSamePipelineAndNotifies() async {
        let env = PipelineFixtures.successfulEnvironment()
        let pipeline = pipeline(env)
        let notifier = RecordingUserNotifier()
        let immediate = ImmediateSendService(pipeline: pipeline, notifier: notifier)
        let outcome = await immediate.sendNow(to: .cursor)
        XCTAssertEqual(outcome, .verifiedSent)
        XCTAssertEqual(notifier.events, [.verifiedSent(target: .cursor)])
        XCTAssertTrue(ImmediateSend.confirmationMessage(for: .cursor).contains("focused"))
        XCTAssertFalse(ImmediateSend.confirmationMessage(for: .cursor).lowercased().contains("clipboard"))
    }

    func testDiagnosticsAreReadOnlyAndOmitPromptContent() {
        let query = FakeApplicationQuery()
        query.addInstalled(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            version: "3.20.10",
            path: "/Applications/Cursor.app"
        )
        query.running = [
            RunningApplicationInfo(
                bundleIdentifier: "com.todesktop.230313mzl4w4u92",
                localizedName: "Cursor",
                processIdentifier: 5,
                isActive: false
            )
        ]
        let diagnostics = TargetDiagnostics(query: query, permission: { .notDeterminedOrDenied })
        let snapshot = diagnostics.collect()
        XCTAssertEqual(snapshot.targets.count, 3)
        let cursor = snapshot.targets.first { $0.kind == .cursor }
        XCTAssertEqual(cursor?.detectedBundleIdentifier, "com.todesktop.230313mzl4w4u92")
        XCTAssertEqual(cursor?.isRunning, true)
        XCTAssertEqual(cursor?.isFrontmost, false)
        XCTAssertTrue(cursor?.notes.contains("wrong frontmost state") == true)
        let claude = snapshot.targets.first { $0.kind == .claudeCowork }
        XCTAssertEqual(claude?.isInstalled, false)
        let printed = snapshot.printableDescription
        XCTAssertTrue(printed.contains("read-only"))
        XCTAssertTrue(printed.contains("no prompt content"))
        XCTAssertFalse(printed.contains("/Users/"))
        XCTAssertFalse(printed.lowercased().contains("clipboard"))
    }

    func testSendAlreadyInProgress() async {
        let env = BlockingSendEnvironment()
        let pipeline = LocalSendPipeline(environment: env, timing: .immediate)
        async let first = pipeline.send(to: .cursor)
        await env.started.ensure()
        let second = await pipeline.send(to: .codex)
        XCTAssertEqual(second, .failed(.sendAlreadyInProgress))
        await env.finish()
        _ = await first
    }

    private func pipeline(_ env: FakeSendEnvironment) -> LocalSendPipeline {
        LocalSendPipeline(environment: env, timing: .immediate)
    }
}

final class BlockingSendEnvironment: SendEnvironment, @unchecked Sendable {
    let started = AsyncGate()
    private let finished = AsyncGate()
    var accessibilityStatus: AccessibilityTrustStatus { .trusted }

    func resolve(_ definition: TargetDefinition) -> ResolvedApplication? {
        _ = definition
        return PipelineFixtures.runningCursor()
    }

    func activate(bundleIdentifier: String) async -> ActivationOutcome {
        _ = bundleIdentifier
        await started.open()
        await finished.ensure()
        return .becameFrontmost(processIdentifier: PipelineFixtures.cursorPID)
    }

    func inspectComposer(processIdentifier: Int32) -> ComposerInspection {
        _ = processIdentifier
        return PipelineFixtures.focusedDraft
    }

    func postReturnKey(processIdentifier: Int32) -> KeySubmitResult {
        _ = processIdentifier
        return .posted
    }

    func pressSendButton(processIdentifier: Int32, titles: [String]) -> ButtonPressResult {
        _ = processIdentifier
        _ = titles
        return .notFound
    }

    func sleep(seconds: TimeInterval) async {
        _ = seconds
    }

    func finish() async {
        await finished.open()
    }
}

actor AsyncGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func open() {
        isOpen = true
        let waiting = continuations
        continuations.removeAll()
        waiting.forEach { $0.resume() }
    }

    func ensure() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

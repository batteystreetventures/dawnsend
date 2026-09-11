import DawnSendCore
import Foundation

final class RecordingSendExecutor: SendExecuting, @unchecked Sendable {
    private let lock = NSLock()
    let inner: SendExecuting
    private var _sendCount = 0
    private var _lastTarget: TargetKind?
    private var _lastOutcome: SendOutcome?

    var sendCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _sendCount
    }

    var lastTarget: TargetKind? {
        lock.lock()
        defer { lock.unlock() }
        return _lastTarget
    }

    var lastOutcome: SendOutcome? {
        lock.lock()
        defer { lock.unlock() }
        return _lastOutcome
    }

    init(inner: SendExecuting) {
        self.inner = inner
    }

    func send(to target: TargetKind) async -> SendOutcome {
        recordStart(target: target)
        let outcome = await inner.send(to: target)
        recordOutcome(outcome)
        return outcome
    }

    private func recordStart(target: TargetKind) {
        lock.lock()
        _sendCount += 1
        _lastTarget = target
        lock.unlock()
    }

    private func recordOutcome(_ outcome: SendOutcome) {
        lock.lock()
        _lastOutcome = outcome
        lock.unlock()
    }
}

final class FakeApplicationQuery: ApplicationQuerying, @unchecked Sendable {
    var installed: [String: InstalledApplication] = [:]
    var running: [RunningApplicationInfo] = []

    func application(withBundleIdentifier id: String) -> InstalledApplication? {
        installed[id]
    }

    func runningApplications() -> [RunningApplicationInfo] {
        running
    }

    func addInstalled(
        bundleIdentifier: String,
        displayName: String,
        version: String? = "1.0",
        path: String = "/Applications/\(UUID().uuidString).app"
    ) {
        installed[bundleIdentifier] = InstalledApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            shortVersion: version,
            executableName: displayName,
            pathDescription: PathSanitizer.describe(path: path)
        )
    }
}

final class FakeSendEnvironment: SendEnvironment, @unchecked Sendable {
    var accessibilityStatus: AccessibilityTrustStatus = .trusted
    var resolved: ResolvedApplication?
    var activation: ActivationOutcome = .becameFrontmost(processIdentifier: 42)
    var inspections: [ComposerInspection] = []
    var fallbackInspection: ComposerInspection = .missing
    var returnResult: KeySubmitResult = .posted
    var buttonResult: ButtonPressResult = .notFound
    var returnCount = 0
    var buttonCount = 0
    var activateCount = 0
    var inspectCount = 0
    var sleepCount = 0
    var coordinateClickCount = 0
    var pressedTitles: [String] = []
    var resolveCount = 0

    func resolve(_ definition: TargetDefinition) -> ResolvedApplication? {
        resolveCount += 1
        _ = definition
        return resolved
    }

    func activate(bundleIdentifier: String) async -> ActivationOutcome {
        activateCount += 1
        _ = bundleIdentifier
        return activation
    }

    func inspectComposer(processIdentifier: Int32) -> ComposerInspection {
        inspectCount += 1
        _ = processIdentifier
        if inspections.isEmpty {
            return fallbackInspection
        }
        return inspections.removeFirst()
    }

    func postReturnKey(processIdentifier: Int32) -> KeySubmitResult {
        returnCount += 1
        _ = processIdentifier
        return returnResult
    }

    func pressSendButton(processIdentifier: Int32, titles: [String]) -> ButtonPressResult {
        buttonCount += 1
        pressedTitles = titles
        _ = processIdentifier
        return buttonResult
    }

    func sleep(seconds: TimeInterval) async {
        sleepCount += 1
        _ = seconds
    }
}

enum PipelineFixtures {
    static let cursorPID: Int32 = 4242

    static func runningCursor() -> ResolvedApplication {
        ResolvedApplication(
            kind: .cursor,
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            shortVersion: "3.20.10",
            pathDescription: "/Applications/Cursor.app",
            isInstalled: true,
            isRunning: true,
            isFrontmost: true,
            processIdentifier: cursorPID,
            matchedCandidateIndex: 0
        )
    }

    static func installedButClosedCursor() -> ResolvedApplication {
        var resolved = runningCursor()
        resolved.isRunning = false
        resolved.isFrontmost = false
        resolved.processIdentifier = nil
        return resolved
    }

    static let focusedDraft = ComposerInspection(
        hasFocusedComposer: true,
        valueState: .readableNonEmpty,
        valueLength: 18,
        focusedRole: "AXTextArea",
        sendButtonAvailable: true
    )

    static let clearedDraft = ComposerInspection(
        hasFocusedComposer: true,
        valueState: .readableEmpty,
        valueLength: 0,
        focusedRole: "AXTextArea",
        sendButtonAvailable: true
    )

    static let emptyDraft = ComposerInspection(
        hasFocusedComposer: true,
        valueState: .readableEmpty,
        valueLength: 0,
        focusedRole: "AXTextArea"
    )

    static let unreadableDraft = ComposerInspection(
        hasFocusedComposer: true,
        valueState: .unreadable,
        focusedRole: "AXTextArea",
        sendButtonAvailable: true
    )

    static func successfulEnvironment() -> FakeSendEnvironment {
        let env = FakeSendEnvironment()
        env.resolved = runningCursor()
        env.activation = .becameFrontmost(processIdentifier: cursorPID)
        env.inspections = [focusedDraft, clearedDraft]
        env.fallbackInspection = clearedDraft
        env.returnResult = .posted
        return env
    }
}

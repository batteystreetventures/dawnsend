import Foundation

/// Injected send pipeline for this stage. Prompt 3 replaces this with Accessibility automation.
public final class MockSendExecutor: SendExecuting, @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: SendOutcome
    private var _sendCount = 0
    private var _lastTarget: TargetKind?

    public var sendCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _sendCount
    }

    public var lastTarget: TargetKind? {
        lock.lock()
        defer { lock.unlock() }
        return _lastTarget
    }

    public init(outcome: SendOutcome = .verifiedSent) {
        self.outcome = outcome
    }

    public func setOutcome(_ outcome: SendOutcome) {
        lock.lock()
        self.outcome = outcome
        lock.unlock()
    }

    public func send(to target: TargetKind) async -> SendOutcome {
        record(target: target)
    }

    private func record(target: TargetKind) -> SendOutcome {
        lock.lock()
        _sendCount += 1
        _lastTarget = target
        let result = outcome
        lock.unlock()
        return result
    }
}

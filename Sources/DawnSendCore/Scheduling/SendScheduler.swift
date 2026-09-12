import Foundation

/// Application-lifetime state machine for a single armed send.
public final class SendScheduler: Scheduling {
    public var onChange: (() -> Void)?

    private let clock: Clock
    private let timer: TimerScheduling
    private let store: StatePersisting
    private let power: PowerAssertionManaging
    private let sendExecutor: SendExecuting
    private let notifier: UserNotifying
    private let lock = NSRecursiveLock()

    private var _status: ScheduleStatus = .idle
    private var _target: TargetKind?
    private var _deadline: Date?
    private var _postSendKeepAwake: PostSendKeepAwake = .default
    private var _postSendEndsAt: Date?
    private var _sendAttempted = false
    private var _lastErrorMessage: String?
    private var _lastPowerError: PowerAssertionError?
    private var _disarmAfterSend = false
    private var generation = UUID()

    public init(
        clock: Clock,
        timer: TimerScheduling,
        store: StatePersisting,
        power: PowerAssertionManaging,
        sendExecutor: SendExecuting,
        notifier: UserNotifying
    ) {
        self.clock = clock
        self.timer = timer
        self.store = store
        self.power = power
        self.sendExecutor = sendExecutor
        self.notifier = notifier
    }

    public var status: ScheduleStatus {
        withLock { _status }
    }

    public var deadline: Date? {
        withLock { _deadline }
    }

    public var selectedTarget: TargetKind? {
        withLock { _target }
    }

    public var postSendKeepAwake: PostSendKeepAwake {
        withLock { _postSendKeepAwake }
    }

    public var postSendEndsAt: Date? {
        withLock { _postSendEndsAt }
    }

    public var lastErrorMessage: String? {
        withLock { _lastErrorMessage }
    }

    public var lastPowerError: PowerAssertionError? {
        withLock { _lastPowerError }
    }

    public var isPowerAssertionHeld: Bool {
        power.isHeld
    }

    public var snapshot: SchedulerSnapshot {
        withLock {
            SchedulerSnapshot(
                status: _status,
                target: _target,
                deadline: _deadline,
                postSendKeepAwake: _postSendKeepAwake,
                postSendEndsAt: _postSendEndsAt,
                sendAttempted: _sendAttempted,
                lastErrorMessage: _lastErrorMessage,
                lastPowerError: _lastPowerError,
                isPowerAssertionHeld: power.isHeld,
                lidClosedSupported: LidClosedCapability.isSupported
            )
        }
    }

    public func remainingTime(at now: Date) -> TimeInterval? {
        withLock {
            guard _status == .armed, let deadline = _deadline else {
                return nil
            }
            return deadline.timeIntervalSince(now)
        }
    }

    public func postSendRemainingTime(at now: Date) -> TimeInterval? {
        withLock {
            guard power.isHeld, let end = _postSendEndsAt else {
                return nil
            }
            return end.timeIntervalSince(now)
        }
    }

    public func arm(
        target: TargetKind,
        request: ScheduleRequest,
        postSendKeepAwake: PostSendKeepAwake
    ) throws {
        let now = clock.now
        let deadline: Date
        switch request {
        case .exact(let date):
            deadline = date
        case .relative(let interval):
            guard interval > 0 else {
                throw ArmError.invalidRelativeDelay
            }
            deadline = now.addingTimeInterval(interval)
        }

        guard deadline > now else {
            throw ArmError.deadlineInThePast
        }

        try withLock {
            switch _status {
            case .sending:
                throw ArmError.sendInProgress
            case .armed:
                throw ArmError.alreadyArmed
            case .idle, .sent, .missed, .failed:
                break
            }

            generation = UUID()
            _disarmAfterSend = false
            _target = target
            _deadline = deadline
            _postSendKeepAwake = postSendKeepAwake
            _postSendEndsAt = nil
            _sendAttempted = false
            _lastErrorMessage = nil
            _status = .armed
            persistLocked()
            scheduleLocked(at: deadline)
        }

        acquirePowerAssertion()
        emitChange()
        let notifier = notifier
        Task { @MainActor in
            await notifier.requestAuthorizationIfNeeded()
        }
    }

    public func disarm() {
        var notifyEnded = false
        withLock {
            if _status == .sending {
                _disarmAfterSend = true
                return
            }

            let wasHoldingPostSend = _status == .sent || _status == .failed || _status == .missed
            generation = UUID()
            timer.cancel()
            goIdleLocked(clearDeadline: true)
            persistLocked()
            notifyEnded = wasHoldingPostSend && power.isHeld
            releasePowerLocked()
        }
        if notifyEnded {
            notifier.notify(.postSendKeepAwakeEnded)
        }
        emitChange()
    }

    public func restorePersistedState() {
        let loaded: PersistedScheduleState?
        do {
            loaded = try store.load()
        } catch {
            withLock {
                _lastErrorMessage = "Could not restore the previous schedule."
                goIdleLocked(clearDeadline: true)
            }
            emitChange()
            return
        }

        guard let loaded else {
            emitChange()
            return
        }

        var missedTarget: TargetKind?
        var failedTarget: TargetKind?
        var failedMessage: String?
        let now = clock.now

        withLock {
            _target = loaded.target
            _postSendKeepAwake = loaded.postSendKeepAwake
            _lastErrorMessage = loaded.lastErrorMessage

            switch loaded.status {
            case .idle:
                goIdleLocked(clearDeadline: true)
                _target = loaded.target
                persistLocked()

            case .armed:
                _deadline = loaded.deadline
                if loaded.sendAttempted {
                    markFailedLocked(
                        message: "The previous send was interrupted. DawnSend did not send again.",
                        target: loaded.target
                    )
                    failedTarget = loaded.target
                    failedMessage = _lastErrorMessage
                } else if let deadline = loaded.deadline, deadline > now {
                    generation = UUID()
                    _sendAttempted = false
                    _status = .armed
                    persistLocked()
                    scheduleLocked(at: deadline)
                } else {
                    markMissedLocked()
                    missedTarget = loaded.target
                }

            case .sending:
                _deadline = loaded.deadline
                markFailedLocked(
                    message: "The previous send was interrupted. DawnSend did not send again.",
                    target: loaded.target
                )
                failedTarget = loaded.target
                failedMessage = _lastErrorMessage

            case .sent, .failed, .missed:
                _status = loaded.status
                _deadline = loaded.deadline
                _sendAttempted = loaded.sendAttempted
                _postSendEndsAt = loaded.postSendEndsAt
                restorePostSendHoldLocked(now: now)
                persistLocked()
            }
        }

        if status == .armed || shouldHoldPostSend {
            acquirePowerAssertion()
        }

        if let missedTarget {
            notifier.notify(.missed(target: missedTarget))
        }
        if let failedTarget {
            notifier.notify(.failed(target: failedTarget, message: failedMessage ?? "Send failed."))
        }
        emitChange()
    }

    public func handleClockOrTimeZoneChange() {
        let now = clock.now
        var shouldSend = false
        var shouldExpirePostSend = false

        withLock {
            if _status == .armed, let deadline = _deadline {
                if now >= deadline {
                    shouldSend = true
                } else {
                    scheduleLocked(at: deadline)
                }
            } else if let end = _postSendEndsAt, power.isHeld {
                if now >= end {
                    shouldExpirePostSend = true
                } else {
                    scheduleLocked(at: end)
                }
            }
        }

        if shouldSend {
            startSend()
        } else if shouldExpirePostSend {
            expirePostSend()
        } else {
            emitChange()
        }
    }

    public func prepareForTermination() {
        withLock {
            generation = UUID()
            timer.cancel()
            persistLocked()
            releasePowerLocked()
        }
    }

    private var shouldHoldPostSend: Bool {
        withLock {
            guard _postSendKeepAwake.shouldHoldAfterSend else {
                return false
            }
            switch _status {
            case .sent, .failed:
                if let end = _postSendEndsAt {
                    return end > clock.now
                }
                return _postSendKeepAwake == .untilDisarmed
            case .idle, .armed, .sending, .missed:
                return false
            }
        }
    }

    private func timerDidFire(generation expected: UUID) {
        let now = clock.now
        var shouldSend = false
        var shouldExpirePostSend = false

        withLock {
            guard generation == expected else {
                return
            }
            if _status == .armed, let deadline = _deadline, now >= deadline {
                shouldSend = true
            } else if let end = _postSendEndsAt, now >= end {
                shouldExpirePostSend = true
            }
        }

        if shouldSend {
            startSend()
        } else if shouldExpirePostSend {
            expirePostSend()
        }
    }

    private func startSend() {
        let payload: (TargetKind, UUID)? = withLock {
            guard _status == .armed, let currentTarget = _target, !_sendAttempted else {
                return nil
            }
            _status = .sending
            _sendAttempted = true
            persistLocked()
            return (currentTarget, generation)
        }

        guard let (target, expectedGeneration) = payload else {
            return
        }
        emitChange()

        let executor = sendExecutor
        Task { [weak self] in
            let outcome = await executor.send(to: target)
            self?.finishSend(outcome, target: target, generation: expectedGeneration)
        }
    }

    private func finishSend(_ outcome: SendOutcome, target: TargetKind, generation expected: UUID) {
        var event: UserNotificationEvent?
        withLock {
            guard generation == expected, _status == .sending else {
                return
            }

            switch outcome {
            case .verifiedSent:
                _status = .sent
                _lastErrorMessage = nil
                event = .verifiedSent(target: target)
            case .issuedButNotVerifiable:
                _status = .sent
                _lastErrorMessage = nil
                event = .issuedButNotVerifiable(target: target)
            case .failed(let message):
                _status = .failed
                _lastErrorMessage = message
                event = .failed(target: target, message: message)
            }

            if _disarmAfterSend {
                _disarmAfterSend = false
                goIdleLocked(clearDeadline: false)
                persistLocked()
                releasePowerLocked()
            } else {
                beginPostSendHoldLocked(now: clock.now)
                persistLocked()
            }
        }

        if let event {
            notifier.notify(event)
        }
        emitChange()
    }

    private func beginPostSendHoldLocked(now: Date) {
        guard _postSendKeepAwake.shouldHoldAfterSend else {
            _postSendEndsAt = nil
            timer.cancel()
            releasePowerLocked()
            return
        }

        if let duration = _postSendKeepAwake.holdDuration, duration > 0 {
            let end = now.addingTimeInterval(duration)
            _postSendEndsAt = end
            scheduleLocked(at: end)
        } else {
            _postSendEndsAt = nil
            timer.cancel()
        }
    }

    private func restorePostSendHoldLocked(now: Date) {
        guard _status == .sent || _status == .failed else {
            _postSendEndsAt = nil
            return
        }
        guard _postSendKeepAwake.shouldHoldAfterSend else {
            _postSendEndsAt = nil
            return
        }
        if _postSendKeepAwake == .untilDisarmed {
            _postSendEndsAt = nil
            return
        }
        if let end = _postSendEndsAt, end > now {
            scheduleLocked(at: end)
        } else {
            _postSendEndsAt = nil
        }
    }

    private func expirePostSend() {
        withLock {
            _postSendEndsAt = nil
            persistLocked()
            releasePowerLocked()
        }
        notifier.notify(.postSendKeepAwakeEnded)
        emitChange()
    }

    private func markMissedLocked() {
        generation = UUID()
        timer.cancel()
        _status = .missed
        _sendAttempted = false
        _postSendEndsAt = nil
        _lastErrorMessage = "DawnSend relaunched after the deadline and did not submit a stale draft."
        persistLocked()
        releasePowerLocked()
    }

    private func markFailedLocked(message: String, target: TargetKind?) {
        generation = UUID()
        timer.cancel()
        _status = .failed
        _sendAttempted = true
        _postSendEndsAt = nil
        _lastErrorMessage = message
        persistLocked()
        releasePowerLocked()
        _ = target
    }

    private func goIdleLocked(clearDeadline: Bool) {
        _status = .idle
        _sendAttempted = false
        _postSendEndsAt = nil
        _disarmAfterSend = false
        if clearDeadline {
            _deadline = nil
        }
    }

    private func scheduleLocked(at date: Date) {
        let expected = generation
        timer.schedule(at: date) { [weak self] in
            self?.timerDidFire(generation: expected)
        }
    }

    private func persistLocked() {
        let state = PersistedScheduleState(
            target: _target,
            deadline: _deadline,
            status: _status,
            postSendKeepAwake: _postSendKeepAwake,
            sendAttempted: _sendAttempted,
            postSendEndsAt: _postSendEndsAt,
            lastErrorMessage: _lastErrorMessage
        )
        do {
            try store.save(state)
        } catch {
            _lastErrorMessage = "Could not save schedule state."
        }
    }

    private func acquirePowerAssertion() {
        do {
            try power.acquirePreventingIdleSleep()
            withLock { _lastPowerError = nil }
        } catch let error as PowerAssertionError {
            withLock { _lastPowerError = error }
        } catch {
            withLock {
                _lastPowerError = .acquisitionFailed(status: -1)
            }
        }
    }

    private func releasePowerLocked() {
        power.releaseAssertion()
        _lastPowerError = power.lastError
    }

    private func emitChange() {
        onChange?()
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}


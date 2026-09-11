import DawnSendCore
import Foundation

final class ControllableClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    var now: Date {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _now
        }
        set {
            lock.lock()
            _now = newValue
            lock.unlock()
        }
    }

    init(now: Date) {
        _now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

final class ManualTimerScheduler: TimerScheduling {
    private(set) var nextDeadline: Date?
    private var handler: (() -> Void)?
    private(set) var scheduleCount = 0
    private(set) var cancelCount = 0

    func schedule(at date: Date, handler: @escaping () -> Void) {
        nextDeadline = date
        self.handler = handler
        scheduleCount += 1
    }

    func cancel() {
        cancelCount += 1
        nextDeadline = nil
        handler = nil
    }

    func fire() {
        let pending = handler
        handler = nil
        nextDeadline = nil
        pending?()
    }
}

final class FakePowerAssertionManager: PowerAssertionManaging {
    private(set) var isHeld = false
    private(set) var lastError: PowerAssertionError?
    private(set) var acquireCount = 0
    private(set) var releaseCount = 0
    var acquireError: PowerAssertionError?

    func acquirePreventingIdleSleep() throws {
        if let acquireError {
            lastError = acquireError
            throw acquireError
        }
        acquireCount += 1
        isHeld = true
        lastError = nil
    }

    func releaseAssertion() {
        guard isHeld else {
            return
        }
        releaseCount += 1
        isHeld = false
    }
}

final class RecordingUserNotifier: UserNotifying {
    private(set) var events: [UserNotificationEvent] = []

    func requestAuthorizationIfNeeded() async {}

    func notify(_ event: UserNotificationEvent) {
        events.append(event)
    }
}

struct SchedulerHarness {
    let clock: ControllableClock
    let timer: ManualTimerScheduler
    let store: InMemoryStateStore
    let power: FakePowerAssertionManager
    let sendExecutor: RecordingSendExecutor
    let notifier: RecordingUserNotifier
    let scheduler: SendScheduler

    static func make(
        now: Date = Date(timeIntervalSince1970: 1_700_000_000),
        store: InMemoryStateStore = InMemoryStateStore(),
        sendOutcome: SendOutcome = .verifiedSent,
        power: FakePowerAssertionManager = FakePowerAssertionManager(),
        innerSendExecutor: (any SendExecuting)? = nil
    ) -> SchedulerHarness {
        let clock = ControllableClock(now: now)
        let timer = ManualTimerScheduler()
        let inner = innerSendExecutor ?? MockSendExecutor(outcome: sendOutcome)
        let sendExecutor = RecordingSendExecutor(inner: inner)
        let notifier = RecordingUserNotifier()
        let scheduler = SendScheduler(
            clock: clock,
            timer: timer,
            store: store,
            power: power,
            sendExecutor: sendExecutor,
            notifier: notifier
        )
        return SchedulerHarness(
            clock: clock,
            timer: timer,
            store: store,
            power: power,
            sendExecutor: sendExecutor,
            notifier: notifier,
            scheduler: scheduler
        )
    }
}

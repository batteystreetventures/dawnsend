import Foundation

/// Wall-clock `DispatchSourceTimer`. Clock-change rescheduling is owned by `SendScheduler`.
public final class DispatchTimerScheduler: TimerScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private let queue: DispatchQueue
    private var source: DispatchSourceTimer?
    public private(set) var nextDeadline: Date?

    public init(queue: DispatchQueue = DispatchQueue(label: "app.dawnsend.timer", qos: .userInitiated)) {
        self.queue = queue
    }

    public func schedule(at date: Date, handler: @escaping () -> Void) {
        lock.lock()
        source?.setEventHandler(handler: nil)
        source?.cancel()
        nextDeadline = date

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(wallDeadline: DispatchWallTime.from(date), leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            handler()
            self?.lock.lock()
            self?.source = nil
            self?.nextDeadline = nil
            self?.lock.unlock()
        }
        source = timer
        lock.unlock()
        timer.resume()
    }

    public func cancel() {
        lock.lock()
        source?.setEventHandler(handler: nil)
        source?.cancel()
        source = nil
        nextDeadline = nil
        lock.unlock()
    }
}

extension DispatchWallTime {
    static func from(_ date: Date) -> DispatchWallTime {
        var seconds = date.timeIntervalSince1970
        if seconds < 0 {
            seconds = 0
        }
        let wholeSeconds = time_t(seconds.rounded(.down))
        var nanoseconds = Int((seconds - Double(wholeSeconds)) * 1_000_000_000)
        if nanoseconds < 0 {
            nanoseconds = 0
        }
        if nanoseconds >= 1_000_000_000 {
            nanoseconds = 999_999_999
        }
        return DispatchWallTime(timespec: timespec(tv_sec: wholeSeconds, tv_nsec: nanoseconds))
    }
}

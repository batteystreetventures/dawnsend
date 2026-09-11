import Foundation

/// One-shot absolute-time timer. Tests inject a manual scheduler that never sleeps.
public protocol TimerScheduling: AnyObject {
    var nextDeadline: Date? { get }

    func schedule(at date: Date, handler: @escaping () -> Void)
    func cancel()
}

import Foundation

/// Observes system clock and time-zone changes so the scheduler can reschedule wall-clock deadlines.
public final class SystemClockChangeMonitor {
    private var tokens: [NSObjectProtocol] = []

    public init(handler: @escaping () -> Void) {
        let names: [Notification.Name] = [
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                handler()
            }
            tokens.append(token)
        }
    }

    deinit {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

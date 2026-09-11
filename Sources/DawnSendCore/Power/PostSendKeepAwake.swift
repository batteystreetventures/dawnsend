import Foundation

/// How long to hold a power assertion after a send attempt.
public enum PostSendKeepAwake: String, Codable, CaseIterable, Equatable, Sendable {
    case off
    case oneHour
    case fiveHours
    case untilDisarmed

    public static let `default` = PostSendKeepAwake.fiveHours

    public var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .oneHour:
            return "1 hour"
        case .fiveHours:
            return "5 hours"
        case .untilDisarmed:
            return "Until Disarmed"
        }
    }

    /// Timed hold duration. `nil` means hold until disarm. Zero means do not hold.
    public var holdDuration: TimeInterval? {
        switch self {
        case .off:
            return 0
        case .oneHour:
            return 3600
        case .fiveHours:
            return 5 * 3600
        case .untilDisarmed:
            return nil
        }
    }

    public var shouldHoldAfterSend: Bool {
        self != .off
    }
}

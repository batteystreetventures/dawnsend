import Foundation

/// One-shot schedule request. Relative delays become a concrete timestamp at arm time.
public enum ScheduleRequest: Equatable, Sendable {
    case exact(Date)
    case relative(TimeInterval)

    public static func relative(hours: Int, minutes: Int) -> ScheduleRequest {
        .relative(TimeInterval(hours * 3600 + minutes * 60))
    }
}

public enum ArmError: Error, Equatable, Sendable {
    case deadlineInThePast
    case invalidRelativeDelay
    case sendInProgress
    case alreadyArmed

    public var userMessage: String {
        switch self {
        case .deadlineInThePast:
            return "Choose a time in the future."
        case .invalidRelativeDelay:
            return "Choose a delay greater than zero."
        case .sendInProgress:
            return "A send is already in progress."
        case .alreadyArmed:
            return "A schedule is already armed. Disarm it first."
        }
    }
}

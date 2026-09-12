import Foundation

/// How the user specifies the send time in the popover.
public enum ScheduleMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case relative
    case exact

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .relative:
            return "Delay"
        case .exact:
            return "Exact"
        }
    }
}

/// Editable schedule fields. Relative delays become a concrete timestamp at arm time.
public struct ScheduleForm: Equatable, Sendable {
    public static let maximumHours = 72
    public static let imminentConfirmationThreshold: TimeInterval = 60

    public var target: TargetKind
    public var mode: ScheduleMode
    public var hours: Int
    public var minutes: Int
    public var exactDate: Date
    public var postSendKeepAwake: PostSendKeepAwake

    public init(
        target: TargetKind = .cursor,
        mode: ScheduleMode = .relative,
        hours: Int = 0,
        minutes: Int = 2,
        exactDate: Date = Date().addingTimeInterval(120),
        postSendKeepAwake: PostSendKeepAwake = .default
    ) {
        self.target = target
        self.mode = mode
        self.hours = hours
        self.minutes = minutes
        self.exactDate = exactDate
        self.postSendKeepAwake = postSendKeepAwake
    }

    public var request: ScheduleRequest {
        switch mode {
        case .relative:
            return .relative(hours: hours, minutes: minutes)
        case .exact:
            return .exact(exactDate)
        }
    }

    public func derivedDeadline(now: Date) -> Date? {
        switch mode {
        case .relative:
            let interval = TimeInterval(hours * 3600 + minutes * 60)
            guard interval > 0 else {
                return nil
            }
            return now.addingTimeInterval(interval)
        case .exact:
            return exactDate
        }
    }

    public func validate(now: Date) -> ScheduleFormValidation {
        switch mode {
        case .relative:
            if hours < 0 || minutes < 0 || hours > Self.maximumHours || minutes > 59 {
                return ScheduleFormValidation(
                    isValid: false,
                    message: "Enter a delay between 1 minute and \(Self.maximumHours) hours.",
                    derivedDeadline: nil,
                    remaining: nil,
                    needsImminentConfirmation: false
                )
            }
            if hours == 0 && minutes == 0 {
                return ScheduleFormValidation(
                    isValid: false,
                    message: "Choose a delay greater than zero.",
                    derivedDeadline: nil,
                    remaining: nil,
                    needsImminentConfirmation: false
                )
            }
            let deadline = now.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
            let remaining = deadline.timeIntervalSince(now)
            return ScheduleFormValidation(
                isValid: true,
                message: nil,
                derivedDeadline: deadline,
                remaining: remaining,
                needsImminentConfirmation: remaining > 0 && remaining <= Self.imminentConfirmationThreshold
            )
        case .exact:
            let remaining = exactDate.timeIntervalSince(now)
            if remaining <= 0 {
                return ScheduleFormValidation(
                    isValid: false,
                    message: "Choose a time in the future.",
                    derivedDeadline: exactDate,
                    remaining: remaining,
                    needsImminentConfirmation: false
                )
            }
            return ScheduleFormValidation(
                isValid: true,
                message: nil,
                derivedDeadline: exactDate,
                remaining: remaining,
                needsImminentConfirmation: remaining <= Self.imminentConfirmationThreshold
            )
        }
    }
}

public struct ScheduleFormValidation: Equatable, Sendable {
    public var isValid: Bool
    public var message: String?
    public var derivedDeadline: Date?
    public var remaining: TimeInterval?
    public var needsImminentConfirmation: Bool

    public init(
        isValid: Bool,
        message: String? = nil,
        derivedDeadline: Date? = nil,
        remaining: TimeInterval? = nil,
        needsImminentConfirmation: Bool = false
    ) {
        self.isValid = isValid
        self.message = message
        self.derivedDeadline = derivedDeadline
        self.remaining = remaining
        self.needsImminentConfirmation = needsImminentConfirmation
    }
}

public enum AbsoluteTimeFormatting: Sendable {
    public static func string(from date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

public enum ImminentArmConfirmation: Sendable {
    public static let title = "Send in less than a minute?"

    public static func message(deadline: Date) -> String {
        "DawnSend will submit the focused draft at \(AbsoluteTimeFormatting.string(from: deadline)). Arm only if that draft is ready."
    }
}

import Foundation

/// Observable scheduler projection for UI. Countdown is derived from `deadline`.
public struct SchedulerSnapshot: Equatable, Sendable {
    public var status: ScheduleStatus
    public var target: TargetKind?
    public var deadline: Date?
    public var postSendKeepAwake: PostSendKeepAwake
    public var postSendEndsAt: Date?
    public var sendAttempted: Bool
    public var lastErrorMessage: String?
    public var lastPowerError: PowerAssertionError?
    public var isPowerAssertionHeld: Bool
    public var lidClosedSupported: Bool

    public init(
        status: ScheduleStatus = .idle,
        target: TargetKind? = nil,
        deadline: Date? = nil,
        postSendKeepAwake: PostSendKeepAwake = .default,
        postSendEndsAt: Date? = nil,
        sendAttempted: Bool = false,
        lastErrorMessage: String? = nil,
        lastPowerError: PowerAssertionError? = nil,
        isPowerAssertionHeld: Bool = false,
        lidClosedSupported: Bool = LidClosedCapability.isSupported
    ) {
        self.status = status
        self.target = target
        self.deadline = deadline
        self.postSendKeepAwake = postSendKeepAwake
        self.postSendEndsAt = postSendEndsAt
        self.sendAttempted = sendAttempted
        self.lastErrorMessage = lastErrorMessage
        self.lastPowerError = lastPowerError
        self.isPowerAssertionHeld = isPowerAssertionHeld
        self.lidClosedSupported = lidClosedSupported
    }
}

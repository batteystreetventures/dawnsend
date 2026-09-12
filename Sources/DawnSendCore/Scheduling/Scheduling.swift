import Foundation

/// Application-lifetime scheduler. The authoritative deadline lives here, not in SwiftUI.
public protocol Scheduling: AnyObject {
    var status: ScheduleStatus { get }
    var deadline: Date? { get }
    var selectedTarget: TargetKind? { get }
    var postSendKeepAwake: PostSendKeepAwake { get }
    var postSendEndsAt: Date? { get }
    var lastErrorMessage: String? { get }
    var lastPowerError: PowerAssertionError? { get }
    var isPowerAssertionHeld: Bool { get }
    var snapshot: SchedulerSnapshot { get }

    func remainingTime(at now: Date) -> TimeInterval?
    func postSendRemainingTime(at now: Date) -> TimeInterval?

    func arm(target: TargetKind, request: ScheduleRequest, postSendKeepAwake: PostSendKeepAwake) throws
    func disarm()
    func restorePersistedState()
    func handleClockOrTimeZoneChange()
    func prepareForTermination()
    /// Cancels an armed or in-flight send, persists idle, and releases assertions. Used when the user confirms Quit.
    func cancelScheduleForTermination()
}

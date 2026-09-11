import Foundation

/// Application-lifetime scheduler seam. The real state machine arrives later.
public protocol Scheduling: AnyObject {
    var status: ScheduleStatus { get }
    var deadline: Date? { get }
    var selectedTarget: TargetKind? { get }

    func remainingTime(at now: Date) -> TimeInterval?
}

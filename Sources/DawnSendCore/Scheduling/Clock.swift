import Foundation

/// Wall-clock source for scheduling. Tests inject a controllable clock.
public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}

    public var now: Date {
        Date()
    }
}

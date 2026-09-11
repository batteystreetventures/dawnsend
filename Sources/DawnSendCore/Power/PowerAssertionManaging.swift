/// Native idle-sleep assertion seam. Real IOPM assertions arrive later.
public protocol PowerAssertionManaging: AnyObject {
    var isHeld: Bool { get }

    func acquirePreventingIdleSleep() throws
    func releaseAssertion()
}

public enum PowerAssertionError: Error, Equatable, Sendable {
    case acquisitionFailed(status: Int32)
}

/// Native idle-sleep assertion seam. Tests inject a fake; production uses IOPM.
public protocol PowerAssertionManaging: AnyObject {
    var isHeld: Bool { get }
    var lastError: PowerAssertionError? { get }

    func acquirePreventingIdleSleep() throws
    func releaseAssertion()
}

public enum PowerAssertionError: Error, Equatable, Sendable {
    case acquisitionFailed(status: Int32)
    case releaseFailed(status: Int32)

    public var userMessage: String {
        switch self {
        case .acquisitionFailed:
            return "DawnSend could not keep the Mac awake. The schedule is still armed."
        case .releaseFailed:
            return "DawnSend could not release its keep-awake assertion."
        }
    }
}

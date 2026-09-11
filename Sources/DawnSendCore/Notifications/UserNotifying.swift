/// Local user-notification seam. Authorization and delivery arrive later.
public protocol UserNotifying: AnyObject {
    func requestAuthorizationIfNeeded() async
    func notify(_ event: UserNotificationEvent)
}

public enum UserNotificationEvent: Equatable, Sendable {
    case verifiedSent(target: TargetKind)
    case issuedButNotVerifiable(target: TargetKind)
    case failed(target: TargetKind, message: String)
    case missed(target: TargetKind)
    case postSendKeepAwakeEnded
}

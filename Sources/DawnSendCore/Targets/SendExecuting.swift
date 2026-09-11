/// Cross-app send pipeline seam. Scheduled sends and Test Send share this method.
public protocol SendExecuting: Sendable {
    func send(to target: TargetKind) async -> SendOutcome
}

public enum SendOutcome: Equatable, Sendable {
    case verifiedSent
    case issuedButNotVerifiable
    case failed(message: String)
}

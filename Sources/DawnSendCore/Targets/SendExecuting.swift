/// Cross-app send pipeline seam. Real Accessibility automation arrives later.
public protocol SendExecuting: Sendable {
    func send(to target: TargetKind) async -> SendOutcome
}

public enum SendOutcome: Equatable, Sendable {
    case verifiedSent
    case issuedButNotVerifiable
    case failed(message: String)
}

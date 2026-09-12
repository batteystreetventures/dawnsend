import Foundation

/// Distinguishes a verified submit from a submit that was issued but could not be confirmed.
public enum SendVerification: String, Codable, Equatable, Sendable {
    case verified
    case issuedButNotVerifiable
}

extension SendOutcome {
    public var verification: SendVerification? {
        switch self {
        case .verifiedSent:
            return .verified
        case .issuedButNotVerifiable:
            return .issuedButNotVerifiable
        case .failed:
            return nil
        }
    }
}

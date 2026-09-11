/// Actionable send preflight and delivery failures. Never includes prompt text.
public enum SendFailureReason: Equatable, Sendable {
    case notInstalled(target: TargetKind)
    case notRunning(target: TargetKind)
    case accessibilityDenied
    case activationTimeout(target: TargetKind)
    case noFocusedComposer(target: TargetKind)
    case emptyComposer(target: TargetKind)
    case submitUnsupported(target: TargetKind)
    case submitDidNotTakeEffect(target: TargetKind)
    case sendAlreadyInProgress
    case internalError(String)

    public var userMessage: String {
        switch self {
        case .notInstalled(let target):
            return "\(target.displayName) is not installed. DawnSend looked for the desktop app and did not find it."
        case .notRunning(let target):
            return "\(target.displayName) is not running. Open it, focus the conversation, leave your draft in the composer, then try again. DawnSend will not launch a closed app."
        case .accessibilityDenied:
            return "DawnSend needs Accessibility permission to submit in the target app. Grant access in System Settings › Privacy & Security › Accessibility, then try again."
        case .activationTimeout(let target):
            return "\(target.displayName) did not become the frontmost app in time. Click the app, leave the composer focused, and try again."
        case .noFocusedComposer(let target):
            return "DawnSend did not find a focused message composer in \(target.displayName). Click the draft field and leave it focused. DawnSend will not switch conversations."
        case .emptyComposer(let target):
            return "The focused composer in \(target.displayName) looks empty. Draft your message there first. DawnSend never types or pastes a prompt."
        case .submitUnsupported(let target):
            return "DawnSend could not submit in \(target.displayName). Return is unsupported here and no accessible Send button was found."
        case .submitDidNotTakeEffect(let target):
            return "DawnSend issued Submit in \(target.displayName), but the composer did not change. Confirm the draft is focused and try Test Send."
        case .sendAlreadyInProgress:
            return "A send is already in progress."
        case .internalError(let message):
            return message
        }
    }

    public var isPermissionFailure: Bool {
        self == .accessibilityDenied
    }
}

extension SendOutcome {
    public static func failed(_ reason: SendFailureReason) -> SendOutcome {
        .failed(message: reason.userMessage)
    }

    public var failureReasonHint: String? {
        switch self {
        case .failed(let message):
            return message
        case .verifiedSent, .issuedButNotVerifiable:
            return nil
        }
    }
}

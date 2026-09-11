import Foundation

/// User-initiated send-now API for Prompt 4. Confirmation copy is presented by the UI first.
public enum ImmediateSend: Sendable {
    public static let confirmationTitle = "Send the focused draft now?"

    public static func confirmationMessage(for target: TargetKind) -> String {
        "DawnSend will submit the draft already focused in \(target.displayName). It will not type, paste, or read that prompt into storage. Continue only if that draft is the message you intend to send."
    }
}

public protocol ImmediateSending: Sendable {
    func sendNow(to target: TargetKind) async -> SendOutcome
}

/// Runs the exact same pipeline as a scheduled send. Does not mutate scheduler state.
public final class ImmediateSendService: ImmediateSending, @unchecked Sendable {
    private let pipeline: SendExecuting
    private let notifier: UserNotifying

    public init(pipeline: SendExecuting, notifier: UserNotifying) {
        self.pipeline = pipeline
        self.notifier = notifier
    }

    public func sendNow(to target: TargetKind) async -> SendOutcome {
        let outcome = await pipeline.send(to: target)
        switch outcome {
        case .verifiedSent:
            notifier.notify(.verifiedSent(target: target))
        case .issuedButNotVerifiable:
            notifier.notify(.issuedButNotVerifiable(target: target))
        case .failed(let message):
            notifier.notify(.failed(target: target, message: message))
        }
        return outcome
    }
}

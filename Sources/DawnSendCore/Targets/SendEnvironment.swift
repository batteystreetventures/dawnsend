import Foundation

public enum ActivationOutcome: Equatable, Sendable {
    case becameFrontmost(processIdentifier: Int32)
    case timedOut
    case notRunning
}

public enum ComposerValueState: String, Equatable, Sendable {
    case readableNonEmpty
    case readableEmpty
    case unreadable
}

/// Snapshot of the focused composer. Stores length only — never the draft text.
public struct ComposerInspection: Equatable, Sendable {
    public var hasFocusedComposer: Bool
    public var valueState: ComposerValueState
    public var valueLength: Int?
    public var focusedRole: String?
    public var sendButtonAvailable: Bool

    public init(
        hasFocusedComposer: Bool,
        valueState: ComposerValueState,
        valueLength: Int? = nil,
        focusedRole: String? = nil,
        sendButtonAvailable: Bool = false
    ) {
        self.hasFocusedComposer = hasFocusedComposer
        self.valueState = valueState
        self.valueLength = valueLength
        self.focusedRole = focusedRole
        self.sendButtonAvailable = sendButtonAvailable
    }

    public static let missing = ComposerInspection(
        hasFocusedComposer: false,
        valueState: .unreadable
    )

    public var verificationLimitationNote: String? {
        guard hasFocusedComposer, valueState == .unreadable else {
            return nil
        }
        return "The accessibility tree does not expose composer text, so DawnSend cannot confirm the draft is non-empty or that it cleared after submit."
    }
}

public enum KeySubmitResult: Equatable, Sendable {
    case posted
    case unsupported
    case failed(String)
}

public enum ButtonPressResult: Equatable, Sendable {
    case pressed
    case notFound
    case failed(String)
}

/// System seams used by the send pipeline. No coordinate-click API exists on purpose.
public protocol SendEnvironment: Sendable {
    var accessibilityStatus: AccessibilityTrustStatus { get }
    func resolve(_ definition: TargetDefinition) -> ResolvedApplication?
    func activate(bundleIdentifier: String) async -> ActivationOutcome
    func inspectComposer(processIdentifier: Int32) -> ComposerInspection
    /// Restores focus to an editable composer in the already-open window. Does not navigate conversations or click by coordinates.
    func restoreComposerFocus(processIdentifier: Int32) -> Bool
    func postReturnKey(processIdentifier: Int32) -> KeySubmitResult
    func pressSendButton(processIdentifier: Int32, titles: [String]) -> ButtonPressResult
    func sleep(seconds: TimeInterval) async
}

public struct SendPipelineTiming: Equatable, Sendable {
    public var postSubmitAttempts: Int
    public var postSubmitInterval: TimeInterval
    public var composerFocusAttempts: Int
    public var composerFocusInterval: TimeInterval

    public init(
        postSubmitAttempts: Int,
        postSubmitInterval: TimeInterval,
        composerFocusAttempts: Int = 1,
        composerFocusInterval: TimeInterval = 0
    ) {
        self.postSubmitAttempts = postSubmitAttempts
        self.postSubmitInterval = postSubmitInterval
        self.composerFocusAttempts = composerFocusAttempts
        self.composerFocusInterval = composerFocusInterval
    }

    public static let production = SendPipelineTiming(
        postSubmitAttempts: 8,
        postSubmitInterval: 0.15,
        composerFocusAttempts: 8,
        composerFocusInterval: 0.1
    )
    public static let immediate = SendPipelineTiming(
        postSubmitAttempts: 1,
        postSubmitInterval: 0,
        composerFocusAttempts: 1,
        composerFocusInterval: 0
    )
}

enum ComposerChange: Equatable {
    case submitted
    case changed
    case unchanged
}

enum ComposerDiffer {
    static func compare(before: ComposerInspection, after: ComposerInspection) -> ComposerChange {
        if observablySubmitted(before: before, after: after) {
            return .submitted
        }
        if before.hasFocusedComposer != after.hasFocusedComposer
            || before.valueState != after.valueState
            || before.valueLength != after.valueLength
            || before.sendButtonAvailable != after.sendButtonAvailable
            || before.focusedRole != after.focusedRole {
            return .changed
        }
        return .unchanged
    }

    static func observablySubmitted(before: ComposerInspection, after: ComposerInspection) -> Bool {
        if before.valueState == .readableNonEmpty && after.valueState == .readableEmpty {
            return true
        }
        if before.hasFocusedComposer && !after.hasFocusedComposer {
            return true
        }
        if let beforeLength = before.valueLength,
           let afterLength = after.valueLength,
           before.valueState == .readableNonEmpty,
           afterLength < beforeLength {
            return true
        }
        if before.sendButtonAvailable && !after.sendButtonAvailable {
            return true
        }
        return false
    }
}

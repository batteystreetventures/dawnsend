import Foundation

/// Compact first-run copy. Not a multi-page wizard.
public enum OnboardingCopy: Sendable {
    public static let title = "Before you schedule"

    public static let points: [String] = [
        "DawnSend is local-only. It never reads or stores your prompt except for a brief Accessibility check to see whether the composer is empty.",
        "Open the target app on the right conversation and leave the draft focused. DawnSend does not switch chats or type for you.",
        "Accessibility permission is required to submit.",
        "Keep the Mac unlocked and the lid open. V1 does not work reliably with the lid closed or the Mac locked.",
        "Use Test Send once for each target before relying on a schedule.",
    ]

    public static let continueTitle = "Continue"

    public static let targetExplanation =
        "DawnSend submits the already-open conversation’s focused draft. It never types, pastes, or stores that prompt."

    public static let keepAwakeExplanation =
        "DawnSend keeps the Mac and display awake until it sends."

    public static let notificationsOptional =
        "Notifications are optional. DawnSend still works if you decline them."
}

public protocol FirstRunPersisting: AnyObject {
    var hasCompletedSetup: Bool { get set }
}

public final class UserDefaultsFirstRunStore: FirstRunPersisting {
    public static let key = "dawnsend.hasCompletedSetup"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

public final class InMemoryFirstRunStore: FirstRunPersisting {
    public var hasCompletedSetup: Bool

    public init(hasCompletedSetup: Bool = false) {
        self.hasCompletedSetup = hasCompletedSetup
    }
}

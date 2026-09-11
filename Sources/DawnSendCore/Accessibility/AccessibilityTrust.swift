/// Accessibility TCC state. macOS does not distinguish not-determined from denied without prompting.
public enum AccessibilityTrustStatus: String, Equatable, Sendable {
    case trusted
    case notDeterminedOrDenied

    public var isTrusted: Bool {
        self == .trusted
    }

    public var userFacingSummary: String {
        switch self {
        case .trusted:
            return "Accessibility permission is granted."
        case .notDeterminedOrDenied:
            return "Accessibility permission is not granted (not determined or denied)."
        }
    }
}

/// Non-prompting status, user-initiated trust prompt, and System Settings deep link.
public protocol AccessibilityPermissionManaging: Sendable {
    func status() -> AccessibilityTrustStatus
    /// Uses the supported Accessibility trust API. Call only from a user action.
    func requestTrust()
    func openPrivacySettings()
}

public enum AccessibilityPrivacyPane {
    public static let modernSettingsURL = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    public static let legacySettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    public static let preferredURLs = [modernSettingsURL, legacySettingsURL]
}

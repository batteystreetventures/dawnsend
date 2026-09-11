import AppKit
import ApplicationServices
import DawnSendCore
import Foundation

public final class SystemAccessibilityPermission: AccessibilityPermissionManaging, @unchecked Sendable {
    public init() {}

    public func status() -> AccessibilityTrustStatus {
        if AXIsProcessTrusted() {
            return .trusted
        }
        return .notDeterminedOrDenied
    }

    public func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): kCFBooleanTrue] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openPrivacySettings() {
        for raw in AccessibilityPrivacyPane.preferredURLs {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

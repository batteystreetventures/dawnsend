import DawnSendCore
import XCTest

final class AccessibilityPermissionTests: XCTestCase {
    func testPrivacyPaneURLsPointAtAccessibility() {
        XCTAssertTrue(AccessibilityPrivacyPane.modernSettingsURL.contains("Privacy_Accessibility"))
        XCTAssertTrue(AccessibilityPrivacyPane.legacySettingsURL.contains("Privacy_Accessibility"))
        XCTAssertEqual(AccessibilityPrivacyPane.preferredURLs.count, 2)
    }

    func testUserInitiatedRequestDoesNotRunFromStatusCheck() {
        let permission = FakeAccessibilityPermission()
        XCTAssertEqual(permission.status(), .notDeterminedOrDenied)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertEqual(permission.openCount, 0)

        permission.requestTrust()
        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertEqual(permission.status(), .trusted)

        permission.openPrivacySettings()
        XCTAssertEqual(permission.openCount, 1)
    }

    func testPermissionFailureIsActionableAndDistinct() {
        XCTAssertTrue(SendFailureReason.accessibilityDenied.isPermissionFailure)
        XCTAssertTrue(
            SendFailureReason.accessibilityDenied.userMessage.contains("Privacy & Security › Accessibility")
        )
        XCTAssertFalse(SendFailureReason.noFocusedComposer(target: .cursor).isPermissionFailure)
    }
}

final class FakeAccessibilityPermission: AccessibilityPermissionManaging, @unchecked Sendable {
    var current: AccessibilityTrustStatus = .notDeterminedOrDenied
    var requestCount = 0
    var openCount = 0

    func status() -> AccessibilityTrustStatus {
        current
    }

    func requestTrust() {
        requestCount += 1
        current = .trusted
    }

    func openPrivacySettings() {
        openCount += 1
    }
}

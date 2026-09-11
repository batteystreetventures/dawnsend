import DawnSendCore
import Foundation
import XCTest

final class AppIdentityTests: XCTestCase {
    func testProductIdentity() {
        XCTAssertEqual(AppIdentity.displayName, "DawnSend")
        XCTAssertEqual(AppIdentity.bundleIdentifier, "app.dawnsend")
        XCTAssertEqual(
            AppIdentity.tagline,
            "Keep the Mac awake. Hit Send at the time you choose."
        )
        XCTAssertEqual(AppIdentity.minimumSystemVersion, "13.0")
    }

    func testPackagedInfoPlistMatchesIdentityAndHidesDock() throws {
        let plistURL = RepositoryLayout.root.appendingPathComponent("Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, AppIdentity.displayName)
        XCTAssertEqual(plist["CFBundleName"] as? String, AppIdentity.displayName)
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, AppIdentity.bundleIdentifier)
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, AppIdentity.minimumSystemVersion)
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
    }
}

enum RepositoryLayout {
    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

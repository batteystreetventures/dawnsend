import DawnSendCore
import Foundation
import XCTest

final class TargetResolutionTests: XCTestCase {
    func testCatalogExposesIsolatedDefinitions() {
        XCTAssertEqual(TargetDefinition.codex.kind, .codex)
        XCTAssertEqual(TargetDefinition.cursor.kind, .cursor)
        XCTAssertEqual(TargetDefinition.claudeCowork.kind, .claudeCowork)
        XCTAssertEqual(TargetDefinition.cursor.candidateBundleIdentifiers.first, "com.todesktop.230313mzl4w4u92")
        XCTAssertEqual(TargetDefinition.codex.candidateBundleIdentifiers.first, "com.openai.codex")
        XCTAssertEqual(TargetDefinition.claudeCowork.candidateBundleIdentifiers.first, "com.anthropic.claudefordesktop")
        XCTAssertEqual(TargetDefinition.codex.preferredSubmitStrategy, .returnKey)
        XCTAssertEqual(TargetKind.cursor.systemImageName, TargetDefinition.cursor.icon.systemImageName)
    }

    func testFallbackPrefersFirstInstalledRunningCandidate() {
        let query = FakeApplicationQuery()
        query.addInstalled(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT", path: "/Applications/ChatGPT.app")
        query.addInstalled(bundleIdentifier: "com.openai.chat", displayName: "ChatGPT Legacy", path: "/Applications/ChatGPT Legacy.app")
        query.running = [
            RunningApplicationInfo(
                bundleIdentifier: "com.openai.chat",
                localizedName: "ChatGPT",
                processIdentifier: 11,
                isActive: false
            ),
            RunningApplicationInfo(
                bundleIdentifier: "com.openai.codex",
                localizedName: "ChatGPT",
                processIdentifier: 22,
                isActive: true
            )
        ]

        let resolved = TargetResolver().resolve(definition: .codex, using: query)
        XCTAssertEqual(resolved?.bundleIdentifier, "com.openai.codex")
        XCTAssertEqual(resolved?.matchedCandidateIndex, 0)
        XCTAssertEqual(resolved?.processIdentifier, 22)
        XCTAssertTrue(resolved?.isRunning == true)
    }

    func testFallbackUsesLaterCandidateWhenPreferredIsAbsent() {
        let query = FakeApplicationQuery()
        query.addInstalled(bundleIdentifier: "com.openai.chat", displayName: "ChatGPT", path: "/Applications/ChatGPT.app")
        query.running = [
            RunningApplicationInfo(
                bundleIdentifier: "com.openai.chat",
                localizedName: "ChatGPT",
                processIdentifier: 7,
                isActive: true
            )
        ]

        let resolved = TargetResolver().resolve(definition: .codex, using: query)
        XCTAssertEqual(resolved?.bundleIdentifier, "com.openai.chat")
        XCTAssertEqual(resolved?.matchedCandidateIndex, 1)
    }

    func testProcessNameFallbackWhenBundleIdDiffers() {
        let query = FakeApplicationQuery()
        query.addInstalled(bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor", path: "/Applications/Cursor.app")
        query.running = [
            RunningApplicationInfo(
                bundleIdentifier: "com.example.unexpected-cursor-id",
                localizedName: "Cursor",
                processIdentifier: 9,
                isActive: true
            )
        ]

        let resolved = TargetResolver().resolve(definition: .cursor, using: query)
        XCTAssertEqual(resolved?.bundleIdentifier, "com.example.unexpected-cursor-id")
        XCTAssertTrue(resolved?.matchedByProcessName == true)
        XCTAssertTrue(resolved?.isRunning == true)
    }

    func testNotInstalledWhenNoCandidateMatches() {
        let query = FakeApplicationQuery()
        XCTAssertNil(TargetResolver().resolve(definition: .claudeCowork, using: query))
    }

    func testInstalledButNotRunning() {
        let query = FakeApplicationQuery()
        query.addInstalled(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            path: "/Applications/Claude.app"
        )

        let resolved = TargetResolver().resolve(definition: .claudeCowork, using: query)
        XCTAssertEqual(resolved?.bundleIdentifier, "com.anthropic.claudefordesktop")
        XCTAssertTrue(resolved?.isInstalled == true)
        XCTAssertFalse(resolved?.isRunning == true)
        XCTAssertNil(resolved?.processIdentifier)
    }

    func testPathSanitizerWithholdsHomeDirectories() {
        XCTAssertEqual(PathSanitizer.describe(path: "/Applications/Cursor.app"), "/Applications/Cursor.app")
        XCTAssertEqual(
            PathSanitizer.describe(path: "/Users/someone/Applications/Claude.app"),
            "Claude.app (outside /Applications)"
        )
    }
}

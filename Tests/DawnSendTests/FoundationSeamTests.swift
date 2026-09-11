import DawnSendCore
import Foundation
import XCTest

final class FoundationSeamTests: XCTestCase {
    func testTargetKindsAreStableForPersistence() {
        XCTAssertEqual(TargetKind.allCases.map(\.rawValue), ["codex", "cursor", "claudeCowork"])
        XCTAssertEqual(TargetKind.codex.displayName, "Codex")
        XCTAssertEqual(TargetKind.cursor.displayName, "Cursor")
        XCTAssertEqual(TargetKind.claudeCowork.displayName, "Claude Cowork")
    }

    func testScheduleStatusCoversTheV1StateMachine() {
        XCTAssertEqual(
            ScheduleStatus.allCases,
            [.idle, .armed, .sending, .sent, .missed, .failed]
        )
    }

    func testPostSendKeepAwakeDefaultIsFiveHours() {
        XCTAssertEqual(PostSendKeepAwake.default, .fiveHours)
    }

    func testPersistedStateRoundTripsWithoutPromptText() throws {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let original = PersistedScheduleState(
            target: .cursor,
            deadline: deadline,
            status: .armed,
            postSendKeepAwake: .oneHour
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedScheduleState.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, PersistedScheduleState.currentSchemaVersion)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.lowercased().contains("prompt"))
    }

    func testMalformedPersistedStateFailsToDecode() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PersistedScheduleState.self, from: data))
    }

    func testInMemoryPersistenceSaveLoadAndClear() throws {
        let store = InMemoryStateStore()
        XCTAssertNil(try store.load())

        let state = PersistedScheduleState(target: .codex, status: .idle)
        try store.save(state)
        XCTAssertEqual(try store.load(), state)

        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testFixedClockReturnsInjectedNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = FixedClock(now: now)
        XCTAssertEqual(clock.now, now)
    }
}

private struct FixedClock: Clock {
    var now: Date
}

private final class InMemoryStateStore: StatePersisting {
    private var state: PersistedScheduleState?

    func load() throws -> PersistedScheduleState? {
        state
    }

    func save(_ state: PersistedScheduleState) throws {
        self.state = state
    }

    func clear() throws {
        state = nil
    }
}

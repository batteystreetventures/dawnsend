import Foundation

/// Versionable operational state. Never store prompt text or chat contents.
public struct PersistedScheduleState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var target: TargetKind?
    public var deadline: Date?
    public var status: ScheduleStatus
    public var postSendKeepAwake: PostSendKeepAwake

    public init(
        schemaVersion: Int = PersistedScheduleState.currentSchemaVersion,
        target: TargetKind? = nil,
        deadline: Date? = nil,
        status: ScheduleStatus = .idle,
        postSendKeepAwake: PostSendKeepAwake = .default
    ) {
        self.schemaVersion = schemaVersion
        self.target = target
        self.deadline = deadline
        self.status = status
        self.postSendKeepAwake = postSendKeepAwake
    }
}

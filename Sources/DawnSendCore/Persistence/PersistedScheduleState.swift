import Foundation

/// Versionable operational state. Never store prompt text or chat contents.
public struct PersistedScheduleState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var target: TargetKind?
    public var deadline: Date?
    public var status: ScheduleStatus
    public var postSendKeepAwake: PostSendKeepAwake
    public var sendAttempted: Bool
    public var postSendEndsAt: Date?
    public var lastErrorMessage: String?
    public var lastSendVerification: SendVerification?

    public init(
        schemaVersion: Int = PersistedScheduleState.currentSchemaVersion,
        target: TargetKind? = nil,
        deadline: Date? = nil,
        status: ScheduleStatus = .idle,
        postSendKeepAwake: PostSendKeepAwake = .default,
        sendAttempted: Bool = false,
        postSendEndsAt: Date? = nil,
        lastErrorMessage: String? = nil,
        lastSendVerification: SendVerification? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.target = target
        self.deadline = deadline
        self.status = status
        self.postSendKeepAwake = postSendKeepAwake
        self.sendAttempted = sendAttempted
        self.postSendEndsAt = postSendEndsAt
        self.lastErrorMessage = lastErrorMessage
        self.lastSendVerification = lastSendVerification
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        target = try container.decodeIfPresent(TargetKind.self, forKey: .target)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        status = try container.decode(ScheduleStatus.self, forKey: .status)
        postSendKeepAwake = try container.decodeIfPresent(PostSendKeepAwake.self, forKey: .postSendKeepAwake) ?? .default
        sendAttempted = try container.decodeIfPresent(Bool.self, forKey: .sendAttempted) ?? false
        postSendEndsAt = try container.decodeIfPresent(Date.self, forKey: .postSendEndsAt)
        lastErrorMessage = try container.decodeIfPresent(String.self, forKey: .lastErrorMessage)
        lastSendVerification = try container.decodeIfPresent(SendVerification.self, forKey: .lastSendVerification)
    }
}

/// How long to hold a power assertion after a send attempt.
public enum PostSendKeepAwake: String, Codable, CaseIterable, Equatable, Sendable {
    case off
    case oneHour
    case fiveHours
    case untilDisarmed

    public static let `default` = PostSendKeepAwake.fiveHours
}

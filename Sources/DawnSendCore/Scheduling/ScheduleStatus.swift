/// Explicit scheduler states for a single armed send.
public enum ScheduleStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case idle
    case armed
    case sending
    case sent
    case missed
    case failed
}

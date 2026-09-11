/// Symbolic send targets. Concrete bundle identifiers and automation arrive later.
public enum TargetKind: String, Codable, CaseIterable, Equatable, Sendable {
    case codex
    case cursor
    case claudeCowork

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .cursor:
            return "Cursor"
        case .claudeCowork:
            return "Claude Cowork"
        }
    }
}

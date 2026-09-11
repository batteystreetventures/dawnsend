/// Symbolic send target persisted by the scheduler. Concrete identity lives in `TargetDefinition`.
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

    public var systemImageName: String {
        switch self {
        case .codex:
            return "chevron.left.forwardslash.chevron.right"
        case .cursor:
            return "square.and.pencil"
        case .claudeCowork:
            return "bubble.left.and.bubble.right"
        }
    }

    public var definition: TargetDefinition {
        TargetCatalog.production.definition(for: self)
    }
}

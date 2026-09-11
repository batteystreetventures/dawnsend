import Foundation

/// Data-driven send target. Vendor identity changes should be a small patch here.
public struct TargetDefinition: Equatable, Sendable {
    public var kind: TargetKind
    public var displayName: String
    public var icon: TargetIconMetadata
    /// Ordered fallback list. The first installed, running candidate wins.
    public var candidateBundleIdentifiers: [String]
    public var candidateProcessNames: [String]
    public var preferredSubmitStrategy: SubmitKeyStrategy
    public var sendButtonTitles: [String]
    public var notes: String

    public init(
        kind: TargetKind,
        displayName: String,
        icon: TargetIconMetadata,
        candidateBundleIdentifiers: [String],
        candidateProcessNames: [String],
        preferredSubmitStrategy: SubmitKeyStrategy = .returnKey,
        sendButtonTitles: [String] = TargetDefinition.defaultSendButtonTitles,
        notes: String
    ) {
        self.kind = kind
        self.displayName = displayName
        self.icon = icon
        self.candidateBundleIdentifiers = candidateBundleIdentifiers
        self.candidateProcessNames = candidateProcessNames
        self.preferredSubmitStrategy = preferredSubmitStrategy
        self.sendButtonTitles = sendButtonTitles
        self.notes = notes
    }

    public static let defaultSendButtonTitles = [
        "Send",
        "Submit",
        "Send message",
        "Send Message"
    ]
}

public struct TargetIconMetadata: Equatable, Sendable {
    public var systemImageName: String
    public var accessibilityDescription: String

    public init(systemImageName: String, accessibilityDescription: String) {
        self.systemImageName = systemImageName
        self.accessibilityDescription = accessibilityDescription
    }
}

/// V1 submits with Return. Accessible button press is the only fallback.
public enum SubmitKeyStrategy: String, Equatable, Sendable {
    case returnKey
}

public struct TargetCatalog: Equatable, Sendable {
    public var definitions: [TargetKind: TargetDefinition]

    public init(definitions: [TargetKind: TargetDefinition]) {
        self.definitions = definitions
    }

    public static let production = TargetCatalog(
        definitions: [
            .codex: .codex,
            .cursor: .cursor,
            .claudeCowork: .claudeCowork
        ]
    )

    public func definition(for kind: TargetKind) -> TargetDefinition {
        if let definition = definitions[kind] {
            return definition
        }
        return TargetDefinition(
            kind: kind,
            displayName: kind.displayName,
            icon: TargetIconMetadata(
                systemImageName: kind.systemImageName,
                accessibilityDescription: kind.displayName
            ),
            candidateBundleIdentifiers: [],
            candidateProcessNames: [],
            notes: "No definition is registered for this target."
        )
    }

    public var all: [TargetDefinition] {
        TargetKind.allCases.map { definition(for: $0) }
    }
}

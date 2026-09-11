import Foundation

/// Read-only target diagnostics. Never includes prompt text or unsanitized home-directory paths.
public struct TargetDiagnosticReport: Equatable, Sendable {
    public var kind: TargetKind
    public var displayName: String
    public var candidateBundleIdentifiers: [String]
    public var detectedBundleIdentifier: String?
    public var detectedVersion: String?
    public var pathDescription: String?
    public var isInstalled: Bool
    public var isRunning: Bool
    public var isFrontmost: Bool
    public var matchedByProcessName: Bool
    public var permissionStatus: AccessibilityTrustStatus
    public var preferredSubmitStrategy: SubmitKeyStrategy
    public var sendButtonTitles: [String]
    public var notes: [String]

    public init(
        kind: TargetKind,
        displayName: String,
        candidateBundleIdentifiers: [String],
        detectedBundleIdentifier: String? = nil,
        detectedVersion: String? = nil,
        pathDescription: String? = nil,
        isInstalled: Bool,
        isRunning: Bool,
        isFrontmost: Bool,
        matchedByProcessName: Bool = false,
        permissionStatus: AccessibilityTrustStatus,
        preferredSubmitStrategy: SubmitKeyStrategy,
        sendButtonTitles: [String],
        notes: [String]
    ) {
        self.kind = kind
        self.displayName = displayName
        self.candidateBundleIdentifiers = candidateBundleIdentifiers
        self.detectedBundleIdentifier = detectedBundleIdentifier
        self.detectedVersion = detectedVersion
        self.pathDescription = pathDescription
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.isFrontmost = isFrontmost
        self.matchedByProcessName = matchedByProcessName
        self.permissionStatus = permissionStatus
        self.preferredSubmitStrategy = preferredSubmitStrategy
        self.sendButtonTitles = sendButtonTitles
        self.notes = notes
    }

    public var printableBlock: String {
        var lines: [String] = []
        lines.append("\(displayName)")
        lines.append("  installed: \(isInstalled ? "yes" : "no")")
        if let detectedBundleIdentifier {
            lines.append("  bundle: \(detectedBundleIdentifier)")
        } else {
            lines.append("  bundle: (none detected)")
        }
        lines.append("  candidates: \(candidateBundleIdentifiers.joined(separator: ", "))")
        if let detectedVersion {
            lines.append("  version: \(detectedVersion)")
        }
        if let pathDescription {
            lines.append("  location: \(pathDescription)")
        }
        lines.append("  running: \(isRunning ? "yes" : "no")")
        lines.append("  frontmost: \(isFrontmost ? "yes" : "no")")
        if matchedByProcessName {
            lines.append("  matched by process name")
        }
        lines.append("  strategy: Return, fallback AXPress [\(sendButtonTitles.joined(separator: ", "))]")
        for note in notes {
            lines.append("  note: \(note)")
        }
        return lines.joined(separator: "\n")
    }
}

public struct DiagnosticsSnapshot: Equatable, Sendable {
    public var permissionStatus: AccessibilityTrustStatus
    public var targets: [TargetDiagnosticReport]

    public init(permissionStatus: AccessibilityTrustStatus, targets: [TargetDiagnosticReport]) {
        self.permissionStatus = permissionStatus
        self.targets = targets
    }

    public var printableDescription: String {
        var lines: [String] = []
        lines.append("DawnSend diagnostics (read-only; no send; no prompt content)")
        lines.append(permissionStatus.userFacingSummary)
        lines.append("")
        for report in targets {
            lines.append(report.printableBlock)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

public struct TargetDiagnostics: Sendable {
    private let catalog: TargetCatalog
    private let resolver: TargetResolver
    private let query: ApplicationQuerying
    private let permission: @Sendable () -> AccessibilityTrustStatus

    public init(
        catalog: TargetCatalog = .production,
        resolver: TargetResolver = TargetResolver(),
        query: ApplicationQuerying,
        permission: @escaping @Sendable () -> AccessibilityTrustStatus
    ) {
        self.catalog = catalog
        self.resolver = resolver
        self.query = query
        self.permission = permission
    }

    public func collect() -> DiagnosticsSnapshot {
        let status = permission()
        let reports = catalog.all.map { definition in
            report(for: definition, permission: status)
        }
        return DiagnosticsSnapshot(permissionStatus: status, targets: reports)
    }

    private func report(
        for definition: TargetDefinition,
        permission: AccessibilityTrustStatus
    ) -> TargetDiagnosticReport {
        var notes: [String] = [definition.notes]
        guard let resolved = resolver.resolve(definition: definition, using: query) else {
            notes.append("not installed")
            return TargetDiagnosticReport(
                kind: definition.kind,
                displayName: definition.displayName,
                candidateBundleIdentifiers: definition.candidateBundleIdentifiers,
                isInstalled: false,
                isRunning: false,
                isFrontmost: false,
                permissionStatus: permission,
                preferredSubmitStrategy: definition.preferredSubmitStrategy,
                sendButtonTitles: definition.sendButtonTitles,
                notes: notes
            )
        }

        if !resolved.isRunning {
            notes.append("not running")
        }
        if resolved.isRunning && !resolved.isFrontmost {
            notes.append("wrong frontmost state")
        }
        if permission != .trusted {
            notes.append("Accessibility permission is not granted")
        }

        return TargetDiagnosticReport(
            kind: definition.kind,
            displayName: definition.displayName,
            candidateBundleIdentifiers: definition.candidateBundleIdentifiers,
            detectedBundleIdentifier: resolved.bundleIdentifier,
            detectedVersion: resolved.shortVersion,
            pathDescription: resolved.pathDescription,
            isInstalled: resolved.isInstalled,
            isRunning: resolved.isRunning,
            isFrontmost: resolved.isFrontmost,
            matchedByProcessName: resolved.matchedByProcessName,
            permissionStatus: permission,
            preferredSubmitStrategy: definition.preferredSubmitStrategy,
            sendButtonTitles: definition.sendButtonTitles,
            notes: notes
        )
    }
}

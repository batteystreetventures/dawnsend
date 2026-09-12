import Foundation

/// Compact installed/running state for one target row in the popover.
public struct TargetReadiness: Equatable, Sendable {
    public var kind: TargetKind
    public var isInstalled: Bool
    public var isRunning: Bool

    public init(kind: TargetKind, isInstalled: Bool, isRunning: Bool) {
        self.kind = kind
        self.isInstalled = isInstalled
        self.isRunning = isRunning
    }

    public static func unknown(_ kind: TargetKind) -> TargetReadiness {
        TargetReadiness(kind: kind, isInstalled: false, isRunning: false)
    }

    public static func from(_ report: TargetDiagnosticReport) -> TargetReadiness {
        TargetReadiness(kind: report.kind, isInstalled: report.isInstalled, isRunning: report.isRunning)
    }

    public var shortStatus: String {
        if !isInstalled {
            return "Not installed"
        }
        if !isRunning {
            return "Not running"
        }
        return "Ready"
    }

    public var allowsArm: Bool {
        isInstalled
    }

    public var allowsTestSend: Bool {
        isInstalled && isRunning
    }

    public var warning: String? {
        if !isInstalled {
            return "\(kind.displayName) is not installed."
        }
        if !isRunning {
            return "\(kind.displayName) is not running. Open it on the right conversation and leave the draft focused before the send time."
        }
        return nil
    }

    public var accessibilityLabel: String {
        "\(kind.displayName), \(shortStatus)"
    }
}

public enum TargetReadinessCatalog {
    public static func collect(
        query: ApplicationQuerying,
        permission: AccessibilityTrustStatus
    ) -> [TargetKind: TargetReadiness] {
        let snapshot = TargetDiagnostics(
            query: query,
            permission: { permission }
        ).collect()
        return Dictionary(
            uniqueKeysWithValues: snapshot.targets.map { report in
                (report.kind, TargetReadiness.from(report))
            }
        )
    }
}

/// Claude Desktop, already in the Cowork session the user left open. V1 does not navigate there.
extension TargetDefinition {
    public static let claudeCowork = TargetDefinition(
        kind: .claudeCowork,
        displayName: "Claude Cowork",
        icon: TargetIconMetadata(
            systemImageName: "bubble.left.and.bubble.right",
            accessibilityDescription: "Claude Cowork"
        ),
        candidateBundleIdentifiers: [
            "com.anthropic.claudefordesktop",
            "com.anthropic.claude"
        ],
        candidateProcessNames: [
            "Claude"
        ],
        preferredSubmitStrategy: .returnKey,
        notes: "Activates Claude Desktop and uses the already-open Cowork session. It does not switch modes."
    )
}

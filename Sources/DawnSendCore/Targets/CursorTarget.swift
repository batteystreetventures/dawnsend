/// Cursor desktop app. Confirm the installed bundle ID rather than assuming it never changes.
extension TargetDefinition {
    public static let cursor = TargetDefinition(
        kind: .cursor,
        displayName: "Cursor",
        icon: TargetIconMetadata(
            systemImageName: "square.and.pencil",
            accessibilityDescription: "Cursor"
        ),
        candidateBundleIdentifiers: [
            "com.todesktop.230313mzl4w4u92",
            "com.cursor.Cursor"
        ],
        candidateProcessNames: [
            "Cursor"
        ],
        preferredSubmitStrategy: .returnKey,
        notes: "Uses Cursor's current ToDesktop bundle ID first, then a named fallback."
    )
}

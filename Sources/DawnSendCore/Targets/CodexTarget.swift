/// Codex desktop app. Current builds often ship as ChatGPT.app with a Codex bundle ID.
extension TargetDefinition {
    public static let codex = TargetDefinition(
        kind: .codex,
        displayName: "Codex",
        icon: TargetIconMetadata(
            systemImageName: "chevron.left.forwardslash.chevron.right",
            accessibilityDescription: "Codex"
        ),
        candidateBundleIdentifiers: [
            "com.openai.codex",
            "com.openai.chat",
            "com.openai.chatgpt"
        ],
        candidateProcessNames: [
            "ChatGPT",
            "Codex"
        ],
        preferredSubmitStrategy: .returnKey,
        notes: "Prefers the current Codex desktop identity. Some versions appear as ChatGPT."
    )
}

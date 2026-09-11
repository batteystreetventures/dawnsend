import DawnSendCore
import Foundation

public final class SystemSendEnvironment: SendEnvironment, @unchecked Sendable {
    private let query: ApplicationQuerying
    private let permission: AccessibilityPermissionManaging
    private let resolver: TargetResolver
    private let activationTimeout: TimeInterval

    public init(
        query: ApplicationQuerying = SystemApplicationQuery(),
        permission: AccessibilityPermissionManaging,
        resolver: TargetResolver = TargetResolver(),
        activationTimeout: TimeInterval = 2.5
    ) {
        self.query = query
        self.permission = permission
        self.resolver = resolver
        self.activationTimeout = activationTimeout
    }

    public var accessibilityStatus: AccessibilityTrustStatus {
        permission.status()
    }

    public func resolve(_ definition: TargetDefinition) -> ResolvedApplication? {
        resolver.resolve(definition: definition, using: query)
    }

    public func activate(bundleIdentifier: String) async -> ActivationOutcome {
        await ApplicationActivation.activate(
            bundleIdentifier: bundleIdentifier,
            timeout: activationTimeout
        )
    }

    public func inspectComposer(processIdentifier: Int32) -> ComposerInspection {
        SystemAccessibilityAutomation.inspectComposer(processIdentifier: processIdentifier)
    }

    public func postReturnKey(processIdentifier: Int32) -> KeySubmitResult {
        SystemAccessibilityAutomation.postReturnKey(processIdentifier: processIdentifier)
    }

    public func pressSendButton(processIdentifier: Int32, titles: [String]) -> ButtonPressResult {
        SystemAccessibilityAutomation.pressSendButton(processIdentifier: processIdentifier, titles: titles)
    }

    public func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else {
            return
        }
        let nanoseconds = UInt64((seconds * 1_000_000_000).rounded())
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

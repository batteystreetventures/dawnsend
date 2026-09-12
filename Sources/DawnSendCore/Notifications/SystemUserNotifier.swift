import AppKit
import Foundation
import UserNotifications

/// Local notifications. Authorization is requested only when an event needs to be delivered.
public final class SystemUserNotifier: NSObject, UserNotifying, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    public func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return
        }
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
        }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    public func notify(_ event: UserNotificationEvent) {
        Task { @MainActor [weak self] in
            await self?.deliver(event)
        }
    }

    @MainActor
    private func deliver(_ event: UserNotificationEvent) async {
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = AppIdentity.displayName
        content.body = event.body
        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .active
        }
        let request = UNNotificationRequest(
            identifier: "dawnsend.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

public final class NoOpUserNotifier: UserNotifying {
    public init() {}

    public func requestAuthorizationIfNeeded() async {}

    public func notify(_ event: UserNotificationEvent) {}
}

extension UserNotificationEvent {
    public var body: String {
        switch self {
        case .verifiedSent(let target):
            return "Sent to \(target.displayName)."
        case .issuedButNotVerifiable(let target):
            return "Submit was issued to \(target.displayName), but DawnSend could not verify it."
        case .failed(let target, let message):
            return "Send to \(target.displayName) failed: \(message)"
        case .missed(let target):
            return "Missed the scheduled send to \(target.displayName). DawnSend did not submit a stale draft."
        case .postSendKeepAwakeEnded:
            return "Post-send keep-awake ended."
        }
    }
}

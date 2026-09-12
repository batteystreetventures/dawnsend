import AppKit
import DawnSendCore
import SwiftUI
import UserNotifications

@main
struct DawnSendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppIdentity.displayName, systemImage: "clock") {
            MenuBarRootView()
                .environmentObject(appDelegate.services.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let services = AppServices()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--diagnose") {
            let report = services.diagnosticsSnapshot().printableDescription
            FileHandle.standardOutput.write(Data(report.utf8))
            if !report.hasSuffix("\n") {
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                let line: String
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    line = "Notifications: authorized"
                case .denied:
                    line = "Notifications: denied (System Settings › Notifications › DawnSend)"
                case .notDetermined:
                    line = "Notifications: not determined (asked once on Arm or Test Send)"
                @unknown default:
                    line = "Notifications: unknown"
                }
                FileHandle.standardOutput.write(Data("\(line)\n".utf8))
                exit(0)
            }
            return
        }
        services.scheduler.restorePersistedState()
        services.controller.refresh()
        services.controller.refreshPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.scheduler.prepareForTermination()
    }
}

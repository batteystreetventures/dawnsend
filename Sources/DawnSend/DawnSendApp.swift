import AppKit
import DawnSendCore
import SwiftUI

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
        services.scheduler.restorePersistedState()
        services.controller.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.scheduler.prepareForTermination()
    }
}

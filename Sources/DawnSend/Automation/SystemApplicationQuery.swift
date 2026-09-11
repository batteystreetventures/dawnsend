import AppKit
import DawnSendCore
import Foundation

public final class SystemApplicationQuery: ApplicationQuerying, @unchecked Sendable {
    public init() {}

    public func application(withBundleIdentifier id: String) -> InstalledApplication? {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        guard let url else {
            return nil
        }
        let bundle = Bundle(url: url)
        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let executable = bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return InstalledApplication(
            bundleIdentifier: bundle?.bundleIdentifier ?? id,
            displayName: displayName,
            shortVersion: version,
            executableName: executable,
            pathDescription: PathSanitizer.describe(path: url.path)
        )
    }

    public func runningApplications() -> [RunningApplicationInfo] {
        NSWorkspace.shared.runningApplications.map { app in
            RunningApplicationInfo(
                bundleIdentifier: app.bundleIdentifier,
                localizedName: app.localizedName,
                processIdentifier: app.processIdentifier,
                isActive: app.isActive
            )
        }
    }
}

enum ApplicationActivation {
    static func activate(bundleIdentifier: String, timeout: TimeInterval = 2.5) async -> ActivationOutcome {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { !$0.isTerminated }
        guard let running else {
            return .notRunning
        }

        await MainActor.run {
            if #available(macOS 14.0, *) {
                _ = running.activate()
            } else {
                _ = running.activate(options: [.activateIgnoringOtherApps])
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if running.isTerminated {
                return .notRunning
            }
            if running.isActive {
                return .becameFrontmost(processIdentifier: running.processIdentifier)
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return .timedOut
    }
}

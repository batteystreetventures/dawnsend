import AppKit
import Combine
import DawnSendCore
import Foundation

final class SchedulerController: ObservableObject {
    let scheduler: SendScheduler
    private let immediateSend: ImmediateSending
    private let permission: AccessibilityPermissionManaging
    private let notifier: UserNotifying

    @Published private(set) var snapshot: SchedulerSnapshot
    @Published var selectedTarget: TargetKind = .cursor
    @Published var postSendKeepAwake: PostSendKeepAwake = .default
    @Published var mode: ScheduleMode = .relative
    @Published var hours = 0
    @Published var minutes = 2
    @Published var exactDate = Date().addingTimeInterval(120)
    @Published var armErrorMessage: String?
    @Published var accessibilityStatus: AccessibilityTrustStatus = .notDeterminedOrDenied
    @Published var lastImmediateOutcome: SendOutcome?
    @Published var isTestSending = false
    @Published var confirmTestSend = false

    init(
        scheduler: SendScheduler,
        immediateSend: ImmediateSending,
        permission: AccessibilityPermissionManaging,
        notifier: UserNotifying
    ) {
        self.scheduler = scheduler
        self.immediateSend = immediateSend
        self.permission = permission
        self.notifier = notifier
        self.snapshot = scheduler.snapshot
        self.accessibilityStatus = permission.status()
        if let target = scheduler.selectedTarget {
            selectedTarget = target
        }
        postSendKeepAwake = scheduler.postSendKeepAwake
        scheduler.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
        refresh()
    }

    func refresh() {
        snapshot = scheduler.snapshot
        if let target = snapshot.target {
            selectedTarget = target
        }
        postSendKeepAwake = snapshot.postSendKeepAwake
        if snapshot.status != .idle {
            armErrorMessage = nil
        }
    }

    func refreshPermission() {
        accessibilityStatus = permission.status()
    }

    func requestAccessibility() {
        permission.requestTrust()
        refreshPermission()
    }

    func openAccessibilitySettings() {
        permission.openPrivacySettings()
    }

    func arm() {
        armErrorMessage = nil
        let request: ScheduleRequest
        switch mode {
        case .relative:
            request = .relative(hours: hours, minutes: minutes)
        case .exact:
            request = .exact(exactDate)
        }

        do {
            try scheduler.arm(
                target: selectedTarget,
                request: request,
                postSendKeepAwake: postSendKeepAwake
            )
            refresh()
            Task { @MainActor in
                await notifier.requestAuthorizationIfNeeded()
            }
        } catch let error as ArmError {
            armErrorMessage = error.userMessage
        } catch {
            armErrorMessage = "Could not arm the schedule."
        }
    }

    func disarm() {
        scheduler.disarm()
        refresh()
    }

    func sendNow() async {
        await MainActor.run {
            isTestSending = true
            lastImmediateOutcome = nil
            confirmTestSend = false
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        let outcome = await immediateSend.sendNow(to: selectedTarget)
        await MainActor.run {
            lastImmediateOutcome = outcome
            isTestSending = false
            refresh()
            refreshPermission()
            presentTestSendResult(outcome)
        }
    }

    private func presentTestSendResult(_ outcome: SendOutcome) {
        let alert = NSAlert()
        alert.messageText = "Test Send"
        switch outcome {
        case .verifiedSent:
            alert.alertStyle = .informational
            alert.informativeText = "DawnSend verified that the draft was submitted."
        case .issuedButNotVerifiable:
            alert.alertStyle = .informational
            alert.informativeText = "DawnSend issued Submit, but could not verify it from the accessibility tree. Check the chat to confirm."
        case .failed(let message):
            alert.alertStyle = .warning
            alert.informativeText = message
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    var canArm: Bool {
        switch snapshot.status {
        case .idle, .sent, .missed, .failed:
            if mode == .relative {
                return hours > 0 || minutes > 0
            }
            return true
        case .armed, .sending:
            return false
        }
    }

    var canDisarm: Bool {
        snapshot.status == .armed
            || snapshot.status == .sending
            || snapshot.isPowerAssertionHeld
            || snapshot.status == .sent
            || snapshot.status == .failed
            || snapshot.status == .missed
    }

    var canTestSend: Bool {
        snapshot.status != .sending && !isTestSending
    }
}

enum ScheduleMode: String, CaseIterable, Identifiable {
    case relative
    case exact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relative:
            return "Send in"
        case .exact:
            return "Exact time"
        }
    }
}

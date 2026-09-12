import Foundation

public enum StatusTone: Equatable, Sendable {
    case neutral
    case success
    case warning
    case failure
}

public struct StatusPresentation: Equatable, Sendable {
    public var title: String
    public var summary: String
    public var remediation: String?
    public var restoredBanner: String?
    public var showsArmedCountdown: Bool
    public var showsPostSendCountdown: Bool
    public var showsUntilDisarmedKeepAwake: Bool
    public var showsSendingProgress: Bool
    public var tone: StatusTone

    public init(
        title: String,
        summary: String,
        remediation: String? = nil,
        restoredBanner: String? = nil,
        showsArmedCountdown: Bool = false,
        showsPostSendCountdown: Bool = false,
        showsUntilDisarmedKeepAwake: Bool = false,
        showsSendingProgress: Bool = false,
        tone: StatusTone = .neutral
    ) {
        self.title = title
        self.summary = summary
        self.remediation = remediation
        self.restoredBanner = restoredBanner
        self.showsArmedCountdown = showsArmedCountdown
        self.showsPostSendCountdown = showsPostSendCountdown
        self.showsUntilDisarmedKeepAwake = showsUntilDisarmedKeepAwake
        self.showsSendingProgress = showsSendingProgress
        self.tone = tone
    }
}

public struct MenuBarItemState: Equatable, Sendable {
    public var systemImageName: String
    public var title: String?
    public var accessibilityLabel: String
    public var usesLiveUpdates: Bool
    public var updateInterval: TimeInterval

    public init(
        systemImageName: String,
        title: String? = nil,
        accessibilityLabel: String,
        usesLiveUpdates: Bool,
        updateInterval: TimeInterval
    ) {
        self.systemImageName = systemImageName
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.usesLiveUpdates = usesLiveUpdates
        self.updateInterval = updateInterval
    }
}

public struct PopoverPresentation: Equatable, Sendable {
    public var headerStatus: String
    public var permissionWarning: String?
    public var showsSetup: Bool
    public var canArm: Bool
    public var canDisarm: Bool
    public var canTestSend: Bool
    public var canChangeSchedule: Bool
    public var canChangeKeepAwake: Bool
    public var armBlockedReason: String?
    public var needsImminentConfirmation: Bool
    public var derivedDeadlineText: String?
    public var targetWarning: String?
    public var status: StatusPresentation
    public var menuBar: MenuBarItemState
    public var shouldConfirmQuit: Bool
    public var quitWarning: String
    public var testSendConfirmationTitle: String
    public var testSendConfirmationMessage: String
    public var imminentConfirmationTitle: String
    public var imminentConfirmationMessage: String
    public var primaryActionTitle: String
    public var disarmTitle: String
}

/// Pure mapping from scheduler + form + permission into UI-facing state.
public struct PopoverSession: Equatable, Sendable {
    public var snapshot: SchedulerSnapshot
    public var form: ScheduleForm
    public var accessibilityStatus: AccessibilityTrustStatus
    public var selectedReadiness: TargetReadiness
    public var hasCompletedSetup: Bool
    public var isTestSending: Bool
    public var lastImmediateOutcome: SendOutcome?
    public var now: Date

    public init(
        snapshot: SchedulerSnapshot,
        form: ScheduleForm,
        accessibilityStatus: AccessibilityTrustStatus,
        selectedReadiness: TargetReadiness,
        hasCompletedSetup: Bool,
        isTestSending: Bool = false,
        lastImmediateOutcome: SendOutcome? = nil,
        now: Date
    ) {
        self.snapshot = snapshot
        self.form = form
        self.accessibilityStatus = accessibilityStatus
        self.selectedReadiness = selectedReadiness
        self.hasCompletedSetup = hasCompletedSetup
        self.isTestSending = isTestSending
        self.lastImmediateOutcome = lastImmediateOutcome
        self.now = now
    }

    public var validation: ScheduleFormValidation {
        form.validate(now: now)
    }

    public var isScheduleLocked: Bool {
        switch snapshot.status {
        case .armed, .sending:
            return true
        case .idle, .sent, .missed, .failed:
            return false
        }
    }

    public var presentation: PopoverPresentation {
        let validation = validation
        let status = makeStatus()
        let armBlocked = armBlockedReason(validation: validation)
        let deadlineForConfirm = validation.derivedDeadline
        return PopoverPresentation(
            headerStatus: status.title,
            permissionWarning: accessibilityStatus == .trusted
                ? nil
                : "Accessibility is required to submit. Grant access in System Settings, then return here.",
            showsSetup: !hasCompletedSetup,
            canArm: armBlocked == nil,
            canDisarm: canDisarm,
            canTestSend: canTestSend,
            canChangeSchedule: !isScheduleLocked,
            canChangeKeepAwake: !isScheduleLocked,
            armBlockedReason: armBlocked,
            needsImminentConfirmation: armBlocked == nil && validation.needsImminentConfirmation,
            derivedDeadlineText: validation.derivedDeadline.map(AbsoluteTimeFormatting.string(from:)),
            targetWarning: selectedReadiness.warning,
            status: status,
            menuBar: makeMenuBarItem(),
            shouldConfirmQuit: TerminationPolicy.shouldConfirm(status: snapshot.status),
            quitWarning: TerminationPolicy.message(
                target: snapshot.target ?? form.target,
                deadline: snapshot.deadline,
                status: snapshot.status
            ),
            testSendConfirmationTitle: ImmediateSend.confirmationTitle,
            testSendConfirmationMessage: ImmediateSend.confirmationMessage(for: form.target),
            imminentConfirmationTitle: ImminentArmConfirmation.title,
            imminentConfirmationMessage: deadlineForConfirm.map(ImminentArmConfirmation.message(deadline:))
                ?? ImminentArmConfirmation.title,
            primaryActionTitle: "Arm",
            disarmTitle: "Disarm"
        )
    }

    public var canDisarm: Bool {
        snapshot.status == .armed
            || snapshot.status == .sending
            || snapshot.isPowerAssertionHeld
    }

    public var canTestSend: Bool {
        snapshot.status != .sending
            && !isTestSending
            && accessibilityStatus == .trusted
            && selectedReadiness.allowsTestSend
    }

    public func armBlockedReason(validation: ScheduleFormValidation) -> String? {
        if !hasCompletedSetup {
            return "Read the setup notes, then continue."
        }
        if isScheduleLocked {
            if snapshot.status == .sending {
                return "A send is already in progress."
            }
            return "A schedule is already armed. Disarm it first."
        }
        if accessibilityStatus != .trusted {
            return "Grant Accessibility permission before arming."
        }
        if !selectedReadiness.allowsArm {
            return selectedReadiness.warning
        }
        if !validation.isValid {
            return validation.message ?? "Choose a valid send time."
        }
        return nil
    }

    public func menuBarItem(at date: Date) -> MenuBarItemState {
        var copy = self
        copy.now = date
        return copy.makeMenuBarItem()
    }

    private func makeStatus() -> StatusPresentation {
        let target = snapshot.target ?? form.target
        let restoredBanner = restoredBannerText()
        switch snapshot.status {
        case .idle:
            return StatusPresentation(
                title: "Idle",
                summary: "No send is scheduled.",
                restoredBanner: restoredBanner,
                tone: .neutral
            )
        case .armed:
            var summary = "Armed for \(target.displayName)"
            if let deadline = snapshot.deadline {
                summary += " at \(AbsoluteTimeFormatting.string(from: deadline))"
            }
            return StatusPresentation(
                title: "Armed",
                summary: summary,
                restoredBanner: restoredBanner,
                showsArmedCountdown: true,
                tone: .neutral
            )
        case .sending:
            return StatusPresentation(
                title: "Sending",
                summary: "Submitting the focused draft in \(target.displayName)…",
                restoredBanner: restoredBanner,
                showsSendingProgress: true,
                tone: .neutral
            )
        case .sent:
            switch snapshot.lastSendVerification {
            case .issuedButNotVerifiable:
                return StatusPresentation(
                    title: "Sent, not verified",
                    summary: "Submit was issued to \(target.displayName), but DawnSend could not verify it.",
                    remediation: "Check the chat to confirm the draft was submitted.",
                    restoredBanner: restoredBanner,
                    showsPostSendCountdown: snapshot.postSendEndsAt != nil,
                    showsUntilDisarmedKeepAwake: showsUntilDisarmedKeepAwake,
                    tone: .warning
                )
            case .verified, .none:
                return StatusPresentation(
                    title: "Sent",
                    summary: snapshot.lastSendVerification == .verified
                        ? "DawnSend verified the draft was submitted to \(target.displayName)."
                        : "DawnSend finished a send to \(target.displayName).",
                    restoredBanner: restoredBanner,
                    showsPostSendCountdown: snapshot.postSendEndsAt != nil,
                    showsUntilDisarmedKeepAwake: showsUntilDisarmedKeepAwake,
                    tone: .success
                )
            }
        case .missed:
            return StatusPresentation(
                title: "Missed",
                summary: snapshot.lastErrorMessage
                    ?? "DawnSend relaunched after the deadline and did not submit a stale draft.",
                remediation: "Open \(target.displayName), focus the draft, and arm a new time. DawnSend never auto-sends a restored schedule that already expired.",
                restoredBanner: restoredBanner,
                tone: .warning
            )
        case .failed:
            return StatusPresentation(
                title: "Failed",
                summary: snapshot.lastErrorMessage ?? "The send failed.",
                remediation: "Fix the issue above, then use Test Send before arming again.",
                restoredBanner: restoredBanner,
                showsPostSendCountdown: snapshot.postSendEndsAt != nil,
                showsUntilDisarmedKeepAwake: showsUntilDisarmedKeepAwake,
                tone: .failure
            )
        }
    }

    private var showsUntilDisarmedKeepAwake: Bool {
        snapshot.isPowerAssertionHeld
            && snapshot.postSendKeepAwake == .untilDisarmed
            && snapshot.status != .armed
            && snapshot.status != .sending
            && snapshot.postSendEndsAt == nil
    }

    private func restoredBannerText() -> String? {
        guard snapshot.restoredFromPersistence else {
            return nil
        }
        switch snapshot.status {
        case .armed:
            return "Restored after relaunch. This schedule is still armed."
        case .missed:
            return "Restored after relaunch. The scheduled time had already passed, so DawnSend marked it missed and did not send."
        case .failed:
            return "Restored after relaunch. The previous send did not finish, and DawnSend did not send again."
        case .sent:
            return "Restored after relaunch."
        case .idle, .sending:
            return nil
        }
    }

    private func makeMenuBarItem() -> MenuBarItemState {
        let target = snapshot.target ?? form.target
        switch snapshot.status {
        case .armed:
            let remaining = snapshot.deadline.map { $0.timeIntervalSince(now) } ?? 0
            let compact = CountdownFormatting.string(from: remaining, style: .compact)
            var label = "DawnSend, armed, \(target.displayName)"
            if let deadline = snapshot.deadline {
                label += ", sends at \(AbsoluteTimeFormatting.string(from: deadline))"
            }
            label += ", \(CountdownFormatting.spoken(from: remaining)) remaining"
            return MenuBarItemState(
                systemImageName: "clock.fill",
                title: compact,
                accessibilityLabel: label,
                usesLiveUpdates: true,
                updateInterval: CountdownFormatting.menuBarUpdateInterval(remaining: remaining)
            )
        case .sending:
            return MenuBarItemState(
                systemImageName: "clock.fill",
                title: nil,
                accessibilityLabel: "DawnSend, sending to \(target.displayName)",
                usesLiveUpdates: false,
                updateInterval: 30
            )
        case .sent, .missed, .failed, .idle:
            return MenuBarItemState(
                systemImageName: "clock",
                title: nil,
                accessibilityLabel: "DawnSend, \(makeStatus().title.lowercased())",
                usesLiveUpdates: false,
                updateInterval: 30
            )
        }
    }
}

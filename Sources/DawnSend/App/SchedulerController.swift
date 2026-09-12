import Combine
import DawnSendCore
import Foundation

final class SchedulerController: ObservableObject {
    let scheduler: SendScheduler
    private let immediateSend: ImmediateSending
    private let permission: AccessibilityPermissionManaging
    private let notifier: UserNotifying
    private let query: ApplicationQuerying
    private let firstRun: FirstRunPersisting

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
    @Published var confirmImminentArm = false
    @Published var testSendAlert: TestSendAlert?
    @Published var hasCompletedSetup = false
    @Published var readinessByTarget: [TargetKind: TargetReadiness] = [:]

    init(
        scheduler: SendScheduler,
        immediateSend: ImmediateSending,
        permission: AccessibilityPermissionManaging,
        notifier: UserNotifying,
        query: ApplicationQuerying,
        firstRun: FirstRunPersisting = UserDefaultsFirstRunStore()
    ) {
        self.scheduler = scheduler
        self.immediateSend = immediateSend
        self.permission = permission
        self.notifier = notifier
        self.query = query
        self.firstRun = firstRun
        self.snapshot = scheduler.snapshot
        self.accessibilityStatus = permission.status()
        self.hasCompletedSetup = firstRun.hasCompletedSetup
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
        refreshTargetReadiness()
    }

    var form: ScheduleForm {
        ScheduleForm(
            target: selectedTarget,
            mode: mode,
            hours: hours,
            minutes: minutes,
            exactDate: exactDate,
            postSendKeepAwake: postSendKeepAwake
        )
    }

    func session(at now: Date = Date()) -> PopoverSession {
        PopoverSession(
            snapshot: snapshot,
            form: form,
            accessibilityStatus: accessibilityStatus,
            selectedReadiness: readiness(for: selectedTarget),
            hasCompletedSetup: hasCompletedSetup,
            isTestSending: isTestSending,
            lastImmediateOutcome: lastImmediateOutcome,
            now: now
        )
    }

    func readiness(for kind: TargetKind) -> TargetReadiness {
        readinessByTarget[kind] ?? .unknown(kind)
    }

    func refresh() {
        snapshot = scheduler.snapshot
        if snapshot.restoredFromPersistence {
            firstRun.hasCompletedSetup = true
            hasCompletedSetup = true
        }
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

    func refreshTargetReadiness() {
        readinessByTarget = TargetReadinessCatalog.collect(
            query: query,
            permission: permission.status()
        )
    }

    func refreshUserFacingState() {
        refreshPermission()
        refreshTargetReadiness()
        refresh()
    }

    func acknowledgeSetup() {
        firstRun.hasCompletedSetup = true
        hasCompletedSetup = true
    }

    func requestAccessibility() {
        permission.requestTrust()
        refreshPermission()
    }

    func openAccessibilitySettings() {
        permission.openPrivacySettings()
    }

    func armTapped() {
        armErrorMessage = nil
        let session = session(at: Date())
        if let reason = session.presentation.armBlockedReason {
            armErrorMessage = reason
            return
        }
        if session.presentation.needsImminentConfirmation {
            confirmImminentArm = true
            return
        }
        performArm()
    }

    func confirmAndArm() {
        confirmImminentArm = false
        performArm()
    }

    func performArm() {
        armErrorMessage = nil
        do {
            try scheduler.arm(
                target: selectedTarget,
                request: form.request,
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
        let outcome = await immediateSend.sendNow(to: selectedTarget)
        await MainActor.run {
            lastImmediateOutcome = outcome
            isTestSending = false
            refreshUserFacingState()
            testSendAlert = TestSendAlert(outcome: outcome)
        }
    }

    var canArm: Bool {
        session().presentation.canArm
    }

    var canDisarm: Bool {
        session().presentation.canDisarm
    }

    var canTestSend: Bool {
        session().presentation.canTestSend
    }
}

enum TestSendAlert: Identifiable, Equatable {
    case verified
    case unverified
    case failed(String)

    var id: String {
        switch self {
        case .verified:
            return "verified"
        case .unverified:
            return "unverified"
        case .failed(let message):
            return "failed-\(message)"
        }
    }

    var title: String {
        "Test Send"
    }

    var message: String {
        switch self {
        case .verified:
            return "DawnSend verified that the draft was submitted."
        case .unverified:
            return "DawnSend issued Submit, but could not verify it from the accessibility tree. Check the chat to confirm."
        case .failed(let message):
            return message
        }
    }

    init(outcome: SendOutcome) {
        switch outcome {
        case .verifiedSent:
            self = .verified
        case .issuedButNotVerifiable:
            self = .unverified
        case .failed(let message):
            self = .failed(message)
        }
    }
}

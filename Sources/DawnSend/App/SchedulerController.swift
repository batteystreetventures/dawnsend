import Combine
import DawnSendCore
import Foundation

final class SchedulerController: ObservableObject {
    let scheduler: SendScheduler

    @Published private(set) var snapshot: SchedulerSnapshot
    @Published var selectedTarget: TargetKind = .cursor
    @Published var postSendKeepAwake: PostSendKeepAwake = .default
    @Published var mode: ScheduleMode = .relative
    @Published var hours = 0
    @Published var minutes = 2
    @Published var exactDate = Date().addingTimeInterval(120)
    @Published var armErrorMessage: String?

    init(scheduler: SendScheduler) {
        self.scheduler = scheduler
        self.snapshot = scheduler.snapshot
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

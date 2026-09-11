import DawnSendCore
import Foundation

final class AppServices {
    let scheduler: SendScheduler
    let controller: SchedulerController
    let permission: SystemAccessibilityPermission
    let applicationQuery: SystemApplicationQuery
    private let clockMonitor: SystemClockChangeMonitor
    private let notifier: SystemUserNotifier

    init() {
        let clock = SystemClock()
        let timer = DispatchTimerScheduler()
        let store: any StatePersisting
        if let fileStore = try? FileStateStore.applicationSupportStore() {
            store = fileStore
        } else {
            store = InMemoryStateStore()
        }
        let power = IOPMPowerAssertionManager()
        let permission = SystemAccessibilityPermission()
        let query = SystemApplicationQuery()
        let environment = SystemSendEnvironment(query: query, permission: permission)
        let pipeline = LocalSendPipeline(environment: environment)
        let notifier = SystemUserNotifier()
        let immediateSend = ImmediateSendService(pipeline: pipeline, notifier: notifier)
        let scheduler = SendScheduler(
            clock: clock,
            timer: timer,
            store: store,
            power: power,
            sendExecutor: pipeline,
            notifier: notifier
        )
        self.permission = permission
        self.applicationQuery = query
        self.notifier = notifier
        self.scheduler = scheduler
        self.controller = SchedulerController(
            scheduler: scheduler,
            immediateSend: immediateSend,
            permission: permission
        )
        self.clockMonitor = SystemClockChangeMonitor { [weak scheduler] in
            scheduler?.handleClockOrTimeZoneChange()
        }
    }

    func diagnosticsSnapshot() -> DiagnosticsSnapshot {
        TargetDiagnostics(
            query: applicationQuery,
            permission: { [permission] in
                permission.status()
            }
        ).collect()
    }
}

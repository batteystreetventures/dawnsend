import DawnSendCore
import Foundation

final class AppServices {
    let scheduler: SendScheduler
    let controller: SchedulerController
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
        let sendExecutor = MockSendExecutor(outcome: .verifiedSent)
        let notifier = SystemUserNotifier()
        let scheduler = SendScheduler(
            clock: clock,
            timer: timer,
            store: store,
            power: power,
            sendExecutor: sendExecutor,
            notifier: notifier
        )
        self.notifier = notifier
        self.scheduler = scheduler
        self.controller = SchedulerController(scheduler: scheduler)
        self.clockMonitor = SystemClockChangeMonitor { [weak scheduler] in
            scheduler?.handleClockOrTimeZoneChange()
        }
    }
}

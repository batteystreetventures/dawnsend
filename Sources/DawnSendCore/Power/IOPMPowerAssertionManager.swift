import Foundation
import IOKit.pwr_mgt

/// Holds native IOPM assertions that prevent idle system sleep and idle display sleep.
/// Does not prevent sleep when the lid is closed.
public final class IOPMPowerAssertionManager: PowerAssertionManaging {
    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0

    public private(set) var isHeld = false
    public private(set) var lastError: PowerAssertionError?

    public init() {}

    public func acquirePreventingIdleSleep() throws {
        lastError = nil
        if isHeld {
            return
        }

        var systemID: IOPMAssertionID = 0
        let systemStatus = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "DawnSend scheduled send" as CFString,
            &systemID
        )
        guard systemStatus == kIOReturnSuccess else {
            let error = PowerAssertionError.acquisitionFailed(status: systemStatus)
            lastError = error
            throw error
        }

        var displayID: IOPMAssertionID = 0
        let displayStatus = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "DawnSend scheduled send (display)" as CFString,
            &displayID
        )
        guard displayStatus == kIOReturnSuccess else {
            IOPMAssertionRelease(systemID)
            let error = PowerAssertionError.acquisitionFailed(status: displayStatus)
            lastError = error
            throw error
        }

        systemSleepAssertionID = systemID
        displaySleepAssertionID = displayID
        isHeld = true
    }

    public func releaseAssertion() {
        guard isHeld || systemSleepAssertionID != 0 || displaySleepAssertionID != 0 else {
            return
        }

        var releaseError: PowerAssertionError?
        if systemSleepAssertionID != 0 {
            let status = IOPMAssertionRelease(systemSleepAssertionID)
            if status != kIOReturnSuccess {
                releaseError = .releaseFailed(status: status)
            }
            systemSleepAssertionID = 0
        }
        if displaySleepAssertionID != 0 {
            let status = IOPMAssertionRelease(displaySleepAssertionID)
            if status != kIOReturnSuccess && releaseError == nil {
                releaseError = .releaseFailed(status: status)
            }
            displaySleepAssertionID = 0
        }

        isHeld = false
        lastError = releaseError
    }

    deinit {
        releaseAssertion()
    }
}

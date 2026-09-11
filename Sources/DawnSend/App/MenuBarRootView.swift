import AppKit
import DawnSendCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var controller: SchedulerController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            targetPicker
            schedulePicker
            keepAwakePicker
            statusSection
            actionButtons
            footnotes
            Divider()
            Button("Quit DawnSend") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppIdentity.displayName)
                .font(.headline)
            Text(AppIdentity.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(statusTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var targetPicker: some View {
        Picker("Target", selection: $controller.selectedTarget) {
            ForEach(TargetKind.allCases, id: \.self) { target in
                Text(target.displayName).tag(target)
            }
        }
        .disabled(!controller.canArm)
    }

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("When", selection: $controller.mode) {
                ForEach(ScheduleMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!controller.canArm)

            if controller.mode == .relative {
                Stepper("Hours: \(controller.hours)", value: $controller.hours, in: 0...72)
                    .disabled(!controller.canArm)
                Stepper("Minutes: \(controller.minutes)", value: $controller.minutes, in: 0...59)
                    .disabled(!controller.canArm)
            } else {
                DatePicker(
                    "Deadline",
                    selection: $controller.exactDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(!controller.canArm)
            }
        }
    }

    private var keepAwakePicker: some View {
        Picker("After send", selection: $controller.postSendKeepAwake) {
            ForEach(PostSendKeepAwake.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .disabled(controller.snapshot.status == .armed || controller.snapshot.status == .sending)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let target = controller.snapshot.target {
                Text("Target: \(target.displayName)")
                    .font(.caption)
            }
            if let deadline = controller.snapshot.deadline {
                Text("Deadline: \(deadline.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 4) {
                    if let remaining = controller.scheduler.remainingTime(at: context.date) {
                        Text("Countdown: \(CountdownFormatting.string(from: remaining))")
                            .font(.body.monospacedDigit())
                    }
                    if let remaining = controller.scheduler.postSendRemainingTime(at: context.date) {
                        Text("Keep-awake remaining: \(CountdownFormatting.string(from: remaining))")
                            .font(.caption.monospacedDigit())
                    } else if controller.snapshot.isPowerAssertionHeld,
                              controller.snapshot.postSendKeepAwake == .untilDisarmed,
                              controller.snapshot.status != .armed {
                        Text("Keep-awake until disarmed")
                            .font(.caption)
                    }
                }
            }

            if controller.snapshot.isPowerAssertionHeld {
                Text("Keep-awake assertion is held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = controller.armErrorMessage ?? controller.snapshot.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let powerError = controller.snapshot.lastPowerError {
                Text(powerError.userMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Arm") {
                controller.arm()
            }
            .disabled(!controller.canArm)

            Button("Disarm", role: .destructive) {
                controller.disarm()
            }
            .disabled(!controller.canDisarm)
        }
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Send is simulated in this build.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(LidClosedCapability.userFacingLimitation)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTitle: String {
        switch controller.snapshot.status {
        case .idle:
            return "Idle"
        case .armed:
            return "Armed"
        case .sending:
            return "Sending"
        case .sent:
            return "Sent (simulated)"
        case .missed:
            return "Missed"
        case .failed:
            return "Failed"
        }
    }
}

enum CountdownFormatting {
    static func string(from interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}

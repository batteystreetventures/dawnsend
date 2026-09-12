import AppKit
import DawnSendCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var controller: SchedulerController

    var body: some View {
        let session = controller.session()
        let presentation = session.presentation

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(presentation)
                if presentation.showsSetup {
                    setupCard
                }
                targetSection(session)
                whenSection(session, presentation)
                keepAwakeSection(session)
                statusSection(session, presentation)
                actionButtons(presentation)
                Divider()
                Button(TerminationPolicy.idleQuitButtonTitle) {
                    NSApplication.shared.terminate(nil)
                }
                .accessibilityHint(presentation.shouldConfirmQuit ? presentation.quitWarning : "Quits DawnSend and releases keep-awake.")
            }
            .padding(16)
        }
        .frame(width: 360)
        .frame(maxHeight: 560)
        .onAppear {
            controller.refreshUserFacingState()
        }
        .onChange(of: controller.selectedTarget) { _ in
            controller.refreshTargetReadiness()
        }
        .confirmationDialog(
            presentation.testSendConfirmationTitle,
            isPresented: $controller.confirmTestSend,
            titleVisibility: .visible
        ) {
            Button("Send now") {
                Task {
                    await controller.sendNow()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(presentation.testSendConfirmationMessage)
        }
        .confirmationDialog(
            presentation.imminentConfirmationTitle,
            isPresented: $controller.confirmImminentArm,
            titleVisibility: .visible
        ) {
            Button("Arm") {
                controller.confirmAndArm()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(presentation.imminentConfirmationMessage)
        }
        .alert(
            controller.testSendAlert?.title ?? "Test Send",
            isPresented: testSendAlertPresented
        ) {
            Button("OK", role: .cancel) {
                controller.testSendAlert = nil
            }
        } message: {
            Text(controller.testSendAlert?.message ?? "")
        }
    }

    private var testSendAlertPresented: Binding<Bool> {
        Binding(
            get: { controller.testSendAlert != nil },
            set: { if !$0 { controller.testSendAlert = nil } }
        )
    }

    private func header(_ presentation: PopoverPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppIdentity.displayName)
                    .font(.headline)
                Spacer()
                Text(presentation.headerStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status, \(presentation.headerStatus)")
            }
            Text(AppIdentity.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let warning = presentation.permissionWarning {
                VStack(alignment: .leading, spacing: 8) {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(warning)
                    HStack {
                        Button("Grant Accessibility") {
                            controller.requestAccessibility()
                        }
                        Button("Open Settings") {
                            controller.openAccessibilitySettings()
                        }
                    }
                    .controlSize(.small)
                }
                .padding(8)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(OnboardingCopy.title)
                .font(.subheadline.weight(.semibold))
            ForEach(Array(OnboardingCopy.points.enumerated()), id: \.offset) { _, point in
                Text("• \(point)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(OnboardingCopy.continueTitle) {
                controller.acknowledgeSetup()
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Hides the setup notes and enables Arm when the form is valid.")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func targetSection(_ session: PopoverSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Target")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(TargetKind.allCases, id: \.self) { kind in
                    let readiness = controller.readiness(for: kind)
                    let selected = controller.selectedTarget == kind
                    Button {
                        controller.selectedTarget = kind
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                                .accessibilityHidden(true)
                            Image(systemName: kind.systemImageName)
                                .frame(width: 16)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.displayName)
                                Text(readiness.shortStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.presentation.canChangeSchedule)
                    .accessibilityLabel(readiness.accessibilityLabel)
                    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                }
            }
            Text(OnboardingCopy.targetExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let warning = session.presentation.targetWarning, controller.selectedTarget == session.form.target {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func whenSection(_ session: PopoverSession, _ presentation: PopoverPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("When")
            Picker("When", selection: $controller.mode) {
                ForEach(ScheduleMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!presentation.canChangeSchedule)
            .accessibilityLabel("Schedule mode")

            if controller.mode == .relative {
                Stepper(value: $controller.hours, in: 0...ScheduleForm.maximumHours) {
                    Text("\(controller.hours) hours")
                        .font(.body.monospacedDigit())
                }
                .disabled(!presentation.canChangeSchedule)
                .accessibilityLabel("Hours")
                .accessibilityValue("\(controller.hours)")

                Stepper(value: $controller.minutes, in: 0...59) {
                    Text("\(controller.minutes) minutes")
                        .font(.body.monospacedDigit())
                }
                .disabled(!presentation.canChangeSchedule)
                .accessibilityLabel("Minutes")
                .accessibilityValue("\(controller.minutes)")

                if let deadlineText = presentation.derivedDeadlineText, session.validation.isValid {
                    Text("Sends at \(deadlineText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Sends at \(deadlineText)")
                }
            } else {
                DatePicker(
                    "Date and time",
                    selection: $controller.exactDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(!presentation.canChangeSchedule)
                .accessibilityLabel("Exact date and time")
            }

            if let message = session.validation.message ?? controller.armErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func keepAwakeSection(_ session: PopoverSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Keep awake")
            Text(OnboardingCopy.keepAwakeExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("After send", selection: $controller.postSendKeepAwake) {
                ForEach(PostSendKeepAwake.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .disabled(!session.presentation.canChangeKeepAwake)
            .accessibilityLabel("Keep awake after send")
            Text(LidClosedCapability.userFacingLimitation)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(OnboardingCopy.notificationsOptional)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusSection(_ session: PopoverSession, _ presentation: PopoverPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Status")
            let status = presentation.status
            if let banner = status.restoredBanner {
                Label(banner, systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(banner)
            }
            Text(status.summary)
                .font(.callout)
                .foregroundStyle(statusColor(status.tone))
                .fixedSize(horizontal: false, vertical: true)

            if status.showsSendingProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Sending…")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sending. Wait until DawnSend finishes.")
            }

            if status.showsArmedCountdown || status.showsPostSendCountdown || status.showsUntilDisarmedKeepAwake {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        if status.showsArmedCountdown,
                           let remaining = controller.scheduler.remainingTime(at: context.date) {
                            Text("Countdown \(CountdownFormatting.string(from: remaining, style: .detailed))")
                                .font(.title3.monospacedDigit())
                                .accessibilityLabel(
                                    "Countdown \(CountdownFormatting.spoken(from: remaining))"
                                )
                        }
                        if status.showsPostSendCountdown,
                           let remaining = controller.scheduler.postSendRemainingTime(at: context.date) {
                            Text("Keep-awake remaining \(CountdownFormatting.string(from: remaining, style: .detailed))")
                                .font(.caption.monospacedDigit())
                        } else if status.showsUntilDisarmedKeepAwake {
                            Text("Keep-awake until disarmed")
                                .font(.caption)
                        }
                    }
                }
            }

            if let remediation = status.remediation {
                Text(remediation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let powerError = controller.snapshot.lastPowerError {
                Text(powerError.userMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let outcome = controller.lastImmediateOutcome {
                Text(immediateOutcomeText(outcome))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionButtons(_ presentation: PopoverPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation.canDisarm {
                Button(presentation.disarmTitle, role: .destructive) {
                    controller.disarm()
                }
                .accessibilityLabel("Disarm")
                .accessibilityHint("Stops the timer and releases keep-awake immediately.")
            } else if presentation.showsSetup {
                Button(presentation.primaryActionTitle) {
                    controller.armTapped()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!presentation.canArm)
                .accessibilityLabel("Arm")
                .accessibilityHint(presentation.armBlockedReason ?? "Arms DawnSend for the selected time.")
            } else {
                Button(presentation.primaryActionTitle) {
                    controller.armTapped()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!presentation.canArm)
                .accessibilityLabel("Arm")
                .accessibilityHint(presentation.armBlockedReason ?? "Arms DawnSend for the selected time.")
            }

            Button(controller.isTestSending ? "Sending…" : "Test Send") {
                controller.confirmTestSend = true
            }
            .disabled(!presentation.canTestSend)
            .accessibilityLabel("Test Send")
            .accessibilityHint("Asks for confirmation, then submits the current draft immediately.")
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    private func statusColor(_ tone: StatusTone) -> Color {
        switch tone {
        case .neutral, .success:
            return Color.primary
        case .warning:
            return Color.orange
        case .failure:
            return Color.red
        }
    }

    private func immediateOutcomeText(_ outcome: SendOutcome) -> String {
        switch outcome {
        case .verifiedSent:
            return "Last Test Send: verified."
        case .issuedButNotVerifiable:
            return "Last Test Send: submit issued, not verifiable."
        case .failed(let message):
            return "Last Test Send failed: \(message)"
        }
    }
}

struct MenuBarStatusItem: View {
    @ObservedObject var controller: SchedulerController

    var body: some View {
        let item = controller.session().presentation.menuBar
        Group {
            if item.usesLiveUpdates {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let remaining = controller.scheduler.remainingTime(at: context.date) ?? 0
                    if remaining <= 120 {
                        TimelineView(.periodic(from: context.date, by: 1)) { inner in
                            menuBarLabel(controller.session(at: inner.date).presentation.menuBar)
                        }
                    } else {
                        menuBarLabel(controller.session(at: context.date).presentation.menuBar)
                    }
                }
            } else {
                menuBarLabel(item)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(controller.session().presentation.menuBar.accessibilityLabel)
    }

    @ViewBuilder
    private func menuBarLabel(_ item: MenuBarItemState) -> some View {
        if let title = item.title {
            Label(title, systemImage: item.systemImageName)
        } else {
            Image(systemName: item.systemImageName)
        }
    }
}

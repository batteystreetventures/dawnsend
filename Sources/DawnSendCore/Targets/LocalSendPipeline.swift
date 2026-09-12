import Foundation

/// Conservative local send pipeline shared by scheduled sends and Test Send.
public final class LocalSendPipeline: SendExecuting, @unchecked Sendable {
    private let environment: SendEnvironment
    private let catalog: TargetCatalog
    private let timing: SendPipelineTiming
    private let gate = SendGate()

    public init(
        environment: SendEnvironment,
        catalog: TargetCatalog = .production,
        timing: SendPipelineTiming = .production
    ) {
        self.environment = environment
        self.catalog = catalog
        self.timing = timing
    }

    public func send(to target: TargetKind) async -> SendOutcome {
        guard await gate.enter() else {
            return .failed(.sendAlreadyInProgress)
        }
        let outcome = await sendOnce(to: target)
        await gate.leave()
        return outcome
    }

    private func sendOnce(to target: TargetKind) async -> SendOutcome {

        let definition = catalog.definition(for: target)

        guard let resolved = environment.resolve(definition) else {
            return .failed(.notInstalled(target: target))
        }
        guard resolved.isInstalled else {
            return .failed(.notInstalled(target: target))
        }
        guard resolved.isRunning, resolved.processIdentifier != nil else {
            return .failed(.notRunning(target: target))
        }

        switch environment.accessibilityStatus {
        case .trusted:
            break
        case .notDeterminedOrDenied:
            return .failed(.accessibilityDenied)
        }

        let activePID: Int32
        switch await environment.activate(bundleIdentifier: resolved.bundleIdentifier) {
        case .becameFrontmost(let pidFromActivation):
            activePID = pidFromActivation
        case .timedOut:
            return .failed(.activationTimeout(target: target))
        case .notRunning:
            return .failed(.notRunning(target: target))
        }

        let before = await focusedComposerAfterActivation(pid: activePID)
        guard before.hasFocusedComposer else {
            return .failed(.noFocusedComposer(target: target))
        }
        if before.valueState == .readableEmpty {
            return .failed(.emptyComposer(target: target))
        }

        let contentUnreadable = before.valueState == .unreadable
        var usedButton = false

        switch definition.preferredSubmitStrategy {
        case .returnKey:
            switch environment.postReturnKey(processIdentifier: activePID) {
            case .posted:
                break
            case .unsupported:
                usedButton = true
                switch pressButton(pid: activePID, titles: definition.sendButtonTitles) {
                case .pressed:
                    break
                case .notFound:
                    return .failed(.submitUnsupported(target: target))
                case .failed(let message):
                    return .failed(.internalError(message))
                }
            case .failed(let message):
                return .failed(.internalError(message))
            }
        }

        var afterReturn = before
        let afterReturnPoll = await pollForSubmission(pid: activePID, before: before, startingFrom: afterReturn)
        afterReturn = afterReturnPoll.inspection
        if let verified = afterReturnPoll.outcome {
            return verified
        }

        let returnChange = ComposerDiffer.compare(before: before, after: afterReturn)

        if !usedButton, returnChange == .unchanged, before.valueState == .readableNonEmpty {
            switch pressButton(pid: activePID, titles: definition.sendButtonTitles) {
            case .pressed:
                let afterButtonPoll = await pollForSubmission(
                    pid: activePID,
                    before: before,
                    startingFrom: afterReturn
                )
                if let verified = afterButtonPoll.outcome {
                    return verified
                }
                return finalize(
                    before: before,
                    after: afterButtonPoll.inspection,
                    contentUnreadable: contentUnreadable,
                    target: target
                )
            case .notFound:
                if contentUnreadable {
                    return .issuedButNotVerifiable
                }
                return .failed(.submitDidNotTakeEffect(target: target))
            case .failed(let message):
                return .failed(.internalError(message))
            }
        }

        return finalize(
            before: before,
            after: afterReturn,
            contentUnreadable: contentUnreadable,
            target: target
        )
    }

    private func focusedComposerAfterActivation(pid: Int32) async -> ComposerInspection {
        _ = environment.restoreComposerFocus(processIdentifier: pid)
        if timing.composerFocusInterval > 0 {
            await environment.sleep(seconds: timing.composerFocusInterval)
        }
        var before = environment.inspectComposer(processIdentifier: pid)
        if before.hasFocusedComposer {
            return before
        }

        let attempts = max(1, timing.composerFocusAttempts)
        for _ in 0..<attempts {
            if timing.composerFocusInterval > 0 {
                await environment.sleep(seconds: timing.composerFocusInterval)
            }
            _ = environment.restoreComposerFocus(processIdentifier: pid)
            before = environment.inspectComposer(processIdentifier: pid)
            if before.hasFocusedComposer {
                return before
            }
        }
        return before
    }

    private func pressButton(pid: Int32, titles: [String]) -> ButtonPressResult {
        environment.pressSendButton(processIdentifier: pid, titles: titles)
    }

    private func pollForSubmission(
        pid: Int32,
        before: ComposerInspection,
        startingFrom last: ComposerInspection
    ) async -> (outcome: SendOutcome?, inspection: ComposerInspection) {
        var last = last
        let attempts = max(1, timing.postSubmitAttempts)
        for _ in 0..<attempts {
            if timing.postSubmitInterval > 0 {
                await environment.sleep(seconds: timing.postSubmitInterval)
            }
            last = environment.inspectComposer(processIdentifier: pid)
            if ComposerDiffer.observablySubmitted(before: before, after: last) {
                return (.verifiedSent, last)
            }
        }
        return (nil, last)
    }

    private func finalize(
        before: ComposerInspection,
        after: ComposerInspection,
        contentUnreadable: Bool,
        target: TargetKind
    ) -> SendOutcome {
        switch ComposerDiffer.compare(before: before, after: after) {
        case .submitted:
            return .verifiedSent
        case .changed:
            return .issuedButNotVerifiable
        case .unchanged:
            if contentUnreadable {
                return .issuedButNotVerifiable
            }
            if before.valueState == .readableNonEmpty {
                return .failed(.submitDidNotTakeEffect(target: target))
            }
            return .issuedButNotVerifiable
        }
    }
}

private actor SendGate {
    private var inProgress = false

    func enter() -> Bool {
        if inProgress {
            return false
        }
        inProgress = true
        return true
    }

    func leave() {
        inProgress = false
    }
}

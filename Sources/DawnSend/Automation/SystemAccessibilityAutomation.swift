import AppKit
import ApplicationServices
import CoreGraphics
import DawnSendCore
import Foundation

/// Accessibility-tree inspection and submit actions. Never logs or returns prompt text.
enum SystemAccessibilityAutomation {
    static let composerRoles: Set<String> = [
        "AXTextArea",
        "AXTextField",
        "AXComboBox"
    ]

    static func inspectComposer(processIdentifier pid: Int32) -> ComposerInspection {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.5)
        let sendAvailable = findSendButton(in: app) != nil

        if let focused = copyElement(app, kAXFocusedUIElementAttribute as String),
           let composer = focusedComposer(from: focused),
           isPlausibleComposer(composer) {
            return snapshot(composer, sendAvailable: sendAvailable)
        }

        if let composer = findComposerInMainPane(app: app) {
            return snapshot(composer, sendAvailable: sendAvailable)
        }

        return ComposerInspection(
            hasFocusedComposer: false,
            valueState: .unreadable,
            sendButtonAvailable: sendAvailable
        )
    }

    static func postReturnKey(processIdentifier pid: Int32) -> KeySubmitResult {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return .failed("Could not create a keyboard event source.")
        }
        let returnKey: CGKeyCode = 36
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false)
        else {
            return .unsupported
        }
        keyDown.flags = []
        keyUp.flags = []
        // Electron apps (Cursor, Codex) receive HID-tap Return after they are frontmost.
        // postToPid alone often never reaches the renderer.
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        _ = pid
        return .posted
    }

    static func pressSendButton(processIdentifier pid: Int32, titles: [String]) -> ButtonPressResult {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.5)
        guard let button = findSendButton(in: app, titles: titles) else {
            return .notFound
        }
        let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
        if error == .success {
            return .pressed
        }
        return .failed("The Send button was found but AXPress failed.")
    }

    /// Focuses the chat composer in the already-open window via AXPress. No coordinate clicks.
    static func restoreComposerFocus(processIdentifier pid: Int32) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.5)
        guard let composer = findComposerInMainPane(app: app) else {
            return false
        }
        _ = AXUIElementPerformAction(composer, kAXPressAction as CFString)
        let focused = AXUIElementSetAttributeValue(
            composer,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return focused == .success
    }

    private static func snapshot(_ composer: AXUIElement, sendAvailable: Bool) -> ComposerInspection {
        let role = copyString(composer, kAXRoleAttribute as String)
        let (state, length) = classifyValue(composer)
        return ComposerInspection(
            hasFocusedComposer: true,
            valueState: state,
            valueLength: length,
            focusedRole: role,
            sendButtonAvailable: sendAvailable
        )
    }

    private static func findComposerInMainPane(app: AXUIElement) -> AXUIElement? {
        let root = mainPaneRoot(app: app)
        var remaining = 500
        var candidates: [AXUIElement] = []
        collectComposers(in: root, remaining: &remaining, into: &candidates)
        return preferredComposer(candidates)
    }

    private static func mainPaneRoot(app: AXUIElement) -> AXUIElement {
        let window = copyElement(app, kAXFocusedWindowAttribute as String)
            ?? copyElement(app, kAXMainWindowAttribute as String)
            ?? app
        guard let windowFrame = frame(window) else {
            return window
        }
        let children = copyElements(window, kAXChildrenAttribute as String)
        let panes = children.compactMap { child -> (AXUIElement, CGRect)? in
            guard let childFrame = frame(child) else {
                return nil
            }
            return (child, childFrame)
        }
        let sidebarLimit = windowFrame.minX + 280
        let mainPanes = panes.filter { _, rect in
            rect.minX >= sidebarLimit || rect.width >= max(420, windowFrame.width * 0.45)
        }
        if let widest = mainPanes.max(by: { $0.1.width < $1.1.width }) {
            return widest.0
        }
        return window
    }

    private static func collectComposers(
        in element: AXUIElement,
        remaining: inout Int,
        into candidates: inout [AXUIElement]
    ) {
        guard remaining > 0 else {
            return
        }
        remaining -= 1
        if isPlausibleComposer(element) {
            candidates.append(element)
        }
        for child in copyElements(element, kAXChildrenAttribute as String).prefix(40) {
            collectComposers(in: child, remaining: &remaining, into: &candidates)
        }
    }

    private static func isPlausibleComposer(_ element: AXUIElement) -> Bool {
        let role = copyString(element, kAXRoleAttribute as String) ?? ""
        guard composerRoles.contains(role) else {
            return false
        }
        guard let rect = frame(element) else {
            return role == "AXTextArea"
        }
        return rect.height > 8 && rect.height < 220 && rect.width > 180
    }

    private static func preferredComposer(_ candidates: [AXUIElement]) -> AXUIElement? {
        guard !candidates.isEmpty else {
            return nil
        }
        if let focused = candidates.first(where: { copyBool($0, kAXFocusedAttribute as String) == true }) {
            return focused
        }
        let ranked = candidates.compactMap { element -> (AXUIElement, CGFloat, CGFloat)? in
            guard let rect = frame(element) else {
                return nil
            }
            return (element, rect.maxY, rect.width)
        }
        return ranked.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.2 < rhs.2
            }
            return lhs.1 < rhs.1
        }?.0 ?? candidates.last
    }

    private static func findSendButton(in app: AXUIElement, titles: [String] = TargetDefinition.defaultSendButtonTitles) -> AXUIElement? {
        let normalized = Set(titles.map { $0.lowercased() })
        let root = mainPaneRoot(app: app)
        var remaining = 500
        return findSendButtonWalk(root, titles: normalized, remaining: &remaining)
    }

    private static func findSendButtonWalk(
        _ element: AXUIElement,
        titles: Set<String>,
        remaining: inout Int
    ) -> AXUIElement? {
        guard remaining > 0 else {
            return nil
        }
        remaining -= 1
        let role = copyString(element, kAXRoleAttribute as String) ?? ""
        if role == "AXButton" {
            let labels = [
                copyString(element, kAXTitleAttribute as String),
                copyString(element, kAXDescriptionAttribute as String),
                copyString(element, "AXHelp")
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            if labels.contains(where: { titles.contains($0) || $0 == "send" || $0 == "submit" }) {
                return element
            }
        }
        for child in copyElements(element, kAXChildrenAttribute as String).prefix(40) {
            if let found = findSendButtonWalk(child, titles: titles, remaining: &remaining) {
                return found
            }
        }
        return nil
    }

    private static func focusedComposer(from focused: AXUIElement) -> AXUIElement? {
        if isPlausibleComposer(focused) {
            return focused
        }
        var remaining = 40
        return findNestedComposer(focused, remaining: &remaining)
    }

    private static func findNestedComposer(_ element: AXUIElement, remaining: inout Int) -> AXUIElement? {
        guard remaining > 0 else {
            return nil
        }
        remaining -= 1
        if isPlausibleComposer(element) {
            return element
        }
        for child in copyElements(element, kAXChildrenAttribute as String).prefix(20) {
            if let found = findNestedComposer(child, remaining: &remaining) {
                return found
            }
        }
        return nil
    }

    private static func classifyValue(_ element: AXUIElement) -> (ComposerValueState, Int?) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard error == .success else {
            return (.unreadable, nil)
        }
        guard let value else {
            return (.unreadable, nil)
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let length = trimmed.count
            return (length == 0 ? .readableEmpty : .readableNonEmpty, length)
        }
        if let attributed = value as? NSAttributedString {
            let trimmed = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let length = trimmed.count
            return (length == 0 ? .readableEmpty : .readableNonEmpty, length)
        }
        return (.unreadable, nil)
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue
        else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static func copyElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == CFArrayGetTypeID() else {
            return []
        }
        let array = value as! NSArray
        return array.compactMap { item -> AXUIElement? in
            let object = item as CFTypeRef
            guard CFGetTypeID(object) == AXUIElementGetTypeID() else {
                return nil
            }
            return (object as! AXUIElement)
        }
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }
        return value as? String
    }

    private static func copyBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}

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
        "AXComboBox",
        "AXSearchField"
    ]

    static func inspectComposer(processIdentifier pid: Int32) -> ComposerInspection {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)

        guard let focused = copyElement(app, kAXFocusedUIElementAttribute as String) else {
            return ComposerInspection(
                hasFocusedComposer: false,
                valueState: .unreadable,
                sendButtonAvailable: hasSendButton(app: app, titles: TargetDefinition.defaultSendButtonTitles)
            )
        }

        let composer = focusedComposer(from: focused)
        let sendAvailable = hasSendButton(app: app, titles: TargetDefinition.defaultSendButtonTitles)
        guard let composer else {
            return ComposerInspection(
                hasFocusedComposer: false,
                valueState: .unreadable,
                focusedRole: copyString(focused, kAXRoleAttribute as String),
                sendButtonAvailable: sendAvailable
            )
        }

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

    static func postReturnKey(processIdentifier pid: Int32) -> KeySubmitResult {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failed("Could not create a keyboard event source.")
        }
        let returnKey: CGKeyCode = 36
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false)
        else {
            return .unsupported
        }
        keyDown.postToPid(pid_t(pid))
        keyUp.postToPid(pid_t(pid))
        return .posted
    }

    static func pressSendButton(processIdentifier pid: Int32, titles: [String]) -> ButtonPressResult {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        guard let button = findButton(in: app, titles: titles) else {
            return .notFound
        }
        let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
        if error == .success {
            return .pressed
        }
        return .failed("The Send button was found but AXPress failed.")
    }

    private static func focusedComposer(from focused: AXUIElement) -> AXUIElement? {
        if isComposer(focused) {
            return focused
        }
        return findComposer(in: focused, remaining: 40)
    }

    private static func isComposer(_ element: AXUIElement) -> Bool {
        let role = copyString(element, kAXRoleAttribute as String) ?? ""
        if composerRoles.contains(role) {
            return true
        }
        if copyBool(element, "AXFocused") == true, isValueEditable(element) {
            return true
        }
        return false
    }

    private static func isValueEditable(_ element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        return error == .success && settable.boolValue
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

    private static func hasSendButton(app: AXUIElement, titles: [String]) -> Bool {
        findButton(in: app, titles: titles) != nil
    }

    private static func findButton(in root: AXUIElement, titles: [String]) -> AXUIElement? {
        let normalized = Set(titles.map { $0.lowercased() })
        var remaining = 80
        return findButtonWalk(root, titles: normalized, remaining: &remaining)
    }

    private static func findButtonWalk(
        _ element: AXUIElement,
        titles: Set<String>,
        remaining: inout Int
    ) -> AXUIElement? {
        guard remaining > 0 else {
            return nil
        }
        remaining -= 1
        let role = copyString(element, kAXRoleAttribute as String) ?? ""
        if role == "AXButton" || role == "AXPopUpButton" {
            let labels = [
                copyString(element, kAXTitleAttribute as String),
                copyString(element, kAXDescriptionAttribute as String),
                copyString(element, "AXHelp")
            ].compactMap { $0?.lowercased() }
            if labels.contains(where: { titles.contains($0) }) {
                return element
            }
        }
        guard let children = copyElements(element, kAXChildrenAttribute as String) else {
            return nil
        }
        for child in children.prefix(25) {
            if let found = findButtonWalk(child, titles: titles, remaining: &remaining) {
                return found
            }
        }
        return nil
    }

    private static func findComposer(in element: AXUIElement, remaining: Int) -> AXUIElement? {
        var remaining = remaining
        return findComposerWalk(element, remaining: &remaining)
    }

    private static func findComposerWalk(_ element: AXUIElement, remaining: inout Int) -> AXUIElement? {
        guard remaining > 0 else {
            return nil
        }
        remaining -= 1
        if isComposer(element) {
            return element
        }
        guard let children = copyElements(element, kAXChildrenAttribute as String) else {
            return nil
        }
        for child in children.prefix(20) {
            if copyBool(child, "AXFocused") == true || isComposer(child) {
                if let found = findComposerWalk(child, remaining: &remaining) {
                    return found
                }
            }
        }
        return nil
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

    private static func copyElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == CFArrayGetTypeID() else {
            return nil
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

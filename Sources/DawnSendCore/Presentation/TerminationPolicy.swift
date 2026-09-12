import Foundation

/// Quit behavior. Armed and in-flight sends must not disappear silently.
public enum TerminationPolicy: Sendable {
    public static let title = "Quit DawnSend?"
    public static let confirmButtonTitle = "Quit without sending"
    public static let cancelButtonTitle = "Cancel"
    public static let idleQuitButtonTitle = "Quit DawnSend"

    public static func shouldConfirm(status: ScheduleStatus) -> Bool {
        status == .armed || status == .sending
    }

    public static func message(target: TargetKind?, deadline: Date?, status: ScheduleStatus) -> String {
        switch status {
        case .armed:
            var text = "DawnSend is armed"
            if let target {
                text += " for \(target.displayName)"
            }
            if let deadline {
                text += " at \(AbsoluteTimeFormatting.string(from: deadline))"
            }
            text += ". Quitting now cancels that send and releases keep-awake."
            return text
        case .sending:
            return "A send is in progress. Quitting now may interrupt it and will release keep-awake."
        default:
            return "DawnSend will release any keep-awake assertion and quit."
        }
    }
}

import Foundation

/// Menu-bar and popover countdown text derived from a remaining interval.
public enum CountdownFormatting: Sendable {
    public enum Style: Equatable, Sendable {
        /// Compact status-item text such as `2h 14m` or `45s`.
        case compact
        /// Popover text that keeps seconds while the panel is open.
        case detailed
    }

    public static func string(from interval: TimeInterval, style: Style = .detailed) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        switch style {
        case .compact:
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            if total >= 120 {
                return "\(minutes)m"
            }
            if minutes > 0 {
                return String(format: "%dm %02ds", minutes, seconds)
            }
            return "\(seconds)s"
        case .detailed:
            if hours > 0 {
                return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
            }
            if minutes > 0 {
                return String(format: "%dm %02ds", minutes, seconds)
            }
            return "\(seconds)s"
        }
    }

    /// Spoken remaining time for VoiceOver. Avoids terse abbreviations.
    public static func spoken(from interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }
        if minutes > 0 {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        if seconds > 0 && hours == 0 {
            parts.append(seconds == 1 ? "1 second" : "\(seconds) seconds")
        }
        if parts.isEmpty {
            return "0 seconds"
        }
        return parts.joined(separator: " ")
    }

    /// Cadence for the menu-bar TimelineView while armed. Callers must not schedule this while idle.
    public static func menuBarUpdateInterval(remaining: TimeInterval) -> TimeInterval {
        if remaining > 120 {
            return 30
        }
        return 1
    }
}

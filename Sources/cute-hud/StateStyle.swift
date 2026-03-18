import AppKit

/// Visual style per HUD mode (info, warning, error, critical).
struct StateStyle {
    let dotColor: NSColor
    let defaultTitle: String
    let badgeBg: NSColor
    let badgeText: NSColor
    let badgeBorder: NSColor
    let countdownColor: NSColor

    static let info = StateStyle(
        dotColor:       NSColor(calibratedRed: 0.34, green: 0.92, blue: 0.54, alpha: 1.0),
        defaultTitle:   "ACTIVE",
        badgeBg:        NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.35, alpha: 0.42),
        badgeText:      NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.72, alpha: 1.0),
        badgeBorder:    NSColor(calibratedRed: 0.34, green: 0.92, blue: 0.54, alpha: 0.30),
        countdownColor: NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.72, alpha: 0.95)
    )
    static let warning = StateStyle(
        dotColor:       NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.22, alpha: 1.0),
        defaultTitle:   "TAKING OVER",
        badgeBg:        NSColor(calibratedRed: 0.92, green: 0.45, blue: 0.15, alpha: 0.40),
        badgeText:      NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.55, alpha: 1.0),
        badgeBorder:    NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.22, alpha: 0.30),
        countdownColor: NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.38, alpha: 0.95)
    )
    static let error = StateStyle(
        dotColor:       NSColor(calibratedRed: 0.92, green: 0.26, blue: 0.22, alpha: 1.0),
        defaultTitle:   "ERROR",
        badgeBg:        NSColor(calibratedRed: 0.70, green: 0.18, blue: 0.18, alpha: 0.40),
        badgeText:      NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.62, alpha: 1.0),
        badgeBorder:    NSColor(calibratedRed: 0.70, green: 0.18, blue: 0.18, alpha: 0.30),
        countdownColor: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.62, alpha: 0.95)
    )
    static let critical = StateStyle(
        dotColor:       NSColor(calibratedRed: 1.0, green: 0.20, blue: 0.15, alpha: 1.0),
        defaultTitle:   "DO NOT TOUCH",
        badgeBg:        NSColor(calibratedRed: 0.85, green: 0.12, blue: 0.12, alpha: 0.55),
        badgeText:      NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.50, alpha: 1.0),
        badgeBorder:    NSColor(calibratedRed: 1.0, green: 0.20, blue: 0.15, alpha: 0.40),
        countdownColor: NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.50, alpha: 0.95)
    )
    static let idle = StateStyle(
        dotColor:       NSColor.systemGray,
        defaultTitle:   "IDLE",
        badgeBg:        NSColor(calibratedWhite: 1.0, alpha: 0.08),
        badgeText:      NSColor(calibratedWhite: 1.0, alpha: 0.50),
        badgeBorder:    NSColor(calibratedWhite: 1.0, alpha: 0.06),
        countdownColor: NSColor(calibratedWhite: 1.0, alpha: 0.50)
    )
    static let paused = StateStyle(
        dotColor:       NSColor.systemYellow,
        defaultTitle:   "PAUSED",
        badgeBg:        NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.10, alpha: 0.38),
        badgeText:      NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.48, alpha: 1.0),
        badgeBorder:    NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.10, alpha: 0.30),
        countdownColor: NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.48, alpha: 0.95)
    )

    static func forMode(_ mode: String) -> StateStyle {
        switch mode.lowercased() {
        case "info", "active", "running": return .info
        case "warning", "pending":        return .warning
        case "error":                     return .error
        case "critical":                  return .critical
        case "paused":                    return .paused
        default:                          return .idle
        }
    }
}

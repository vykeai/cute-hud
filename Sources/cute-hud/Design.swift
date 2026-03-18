import AppKit

/// Design constants for the cute-hud panel.
enum HUD {
    static let panelWidth:  CGFloat = 700
    static let panelHeight: CGFloat = 168
    static let corner:      CGFloat = 18
    static let insetX:      CGFloat = 24
    static let insetTop:    CGFloat = 22
    static let badgeH:      CGFloat = 24
    static let badgeInsetR: CGFloat = 24

    static let bgColor      = NSColor(calibratedRed: 0.030, green: 0.024, blue: 0.050, alpha: 0.96)
    static let borderColor  = NSColor(calibratedWhite: 1.0, alpha: 0.10)

    static let textBright    = NSColor(calibratedWhite: 1.0, alpha: 0.97)
    static let textPrimary   = NSColor(calibratedWhite: 1.0, alpha: 0.92)
    static let textSecondary = NSColor(calibratedWhite: 1.0, alpha: 0.55)
    static let textDim       = NSColor(calibratedWhite: 1.0, alpha: 0.40)
    static let factPink      = NSColor(calibratedRed: 0.95, green: 0.76, blue: 0.86, alpha: 0.88)

    static let sheenAlpha: CGFloat = 0.10

    // Blocking overlay
    static let blockingAlpha: CGFloat = 0.35
    static let blockingColor = NSColor(calibratedRed: 0.02, green: 0.01, blue: 0.04, alpha: 1.0)
}

/// Category colors for lure facts (matches vykeai/lure).
func categoryColor(_ category: String) -> NSColor {
    switch category.uppercased() {
    case "ANIMALS":    return NSColor(calibratedRed: 0.30, green: 0.65, blue: 0.35, alpha: 1.0)
    case "NATURE":     return NSColor(calibratedRed: 0.25, green: 0.60, blue: 0.30, alpha: 1.0)
    case "SCIENCE":    return NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.80, alpha: 1.0)
    case "SPACE":      return NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.80, alpha: 1.0)
    case "HISTORY":    return NSColor(calibratedRed: 0.65, green: 0.50, blue: 0.30, alpha: 1.0)
    case "FOOD":       return NSColor(calibratedRed: 0.75, green: 0.45, blue: 0.15, alpha: 1.0)
    case "HUMAN BODY": return NSColor(calibratedRed: 0.75, green: 0.25, blue: 0.35, alpha: 1.0)
    case "PSYCHOLOGY": return NSColor(calibratedRed: 0.70, green: 0.30, blue: 0.70, alpha: 1.0)
    case "TECH":       return NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.75, alpha: 1.0)
    case "COFFEE":     return NSColor(calibratedRed: 0.72, green: 0.45, blue: 0.20, alpha: 1.0)
    default:           return NSColor(calibratedRed: 0.60, green: 0.45, blue: 0.75, alpha: 1.0)
    }
}

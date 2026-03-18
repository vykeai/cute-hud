import AppKit

/// Full-screen semitransparent overlay that blocks mouse interaction.
/// Used in "critical" mode — like Xcode's automation blocking layer.
class BlockingOverlay {
    private var windows: [NSWindow] = []
    private var visible = false

    func show() {
        guard !visible else { return }
        visible = true

        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.level = .statusBar  // above everything except the HUD panel
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.isOpaque = false
            win.backgroundColor = HUD.blockingColor.withAlphaComponent(HUD.blockingAlpha)
            win.appearance = NSAppearance(named: .darkAqua)
            win.hasShadow = false
            win.ignoresMouseEvents = false  // blocks clicks
            win.alphaValue = 1.0
            win.orderFrontRegardless()
            windows.append(win)
        }
    }

    func hide() {
        guard visible else { return }
        visible = false
        for win in windows {
            win.orderOut(nil)
        }
        windows.removeAll()
    }

    var isVisible: Bool { visible }
}

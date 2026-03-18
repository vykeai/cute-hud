import AppKit

/// Full-screen semitransparent overlay that blocks mouse interaction.
/// Used in "critical" mode — like Xcode's automation blocking layer.
///
/// Safety: shows a prominent dismiss hint so the user is never trapped
/// if the controlling process crashes.
///   - Click the ✕ button to dismiss the overlay
///   - Press Escape to dismiss the overlay
///   - Press ⇧⌘⎋ to force-quit cute-hud entirely
class BlockingOverlay {
    private var windows: [NSWindow] = []
    private var visible = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var autoTimeout: Timer?
    private static let maxDurationSeconds: TimeInterval = 30  // never block longer than 30s
    var onDismiss: (() -> Void)?

    func show() {
        guard !visible else { return }
        visible = true

        // Safety: auto-dismiss after max duration so we never trap the user
        autoTimeout?.invalidate()
        autoTimeout = Timer.scheduledTimer(withTimeInterval: Self.maxDurationSeconds, repeats: false) { [weak self] _ in
            guard let self, self.visible else { return }
            self.onDismiss?()
        }

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

            // Dismiss hint — centered on screen, big and obvious
            let container = NSView(frame: screen.frame)
            win.contentView = container

            addDismissHint(to: container, screenFrame: screen.frame)

            win.orderFrontRegardless()
            windows.append(win)
        }

        installKeyboardMonitors()
    }

    func hide() {
        guard visible else { return }
        visible = false
        autoTimeout?.invalidate()
        autoTimeout = nil
        removeKeyboardMonitors()
        for win in windows {
            win.orderOut(nil)
        }
        windows.removeAll()
    }

    var isVisible: Bool { visible }

    // MARK: - Dismiss hint UI

    private func addDismissHint(to container: NSView, screenFrame: NSRect) {
        // Position just below the HUD panel (which sits at top-center)
        let hudBottomY = screenFrame.height - HUD.panelHeight - 12
        let pillH: CGFloat = 40
        let pillW: CGFloat = 300
        let pillX = (screenFrame.width - pillW) / 2
        let pillY = hudBottomY - pillH - 8

        let pill = NSView(frame: NSRect(x: pillX, y: pillY, width: pillW, height: pillH))
        pill.wantsLayer = true
        pill.layer?.cornerRadius = pillH / 2
        pill.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.65).cgColor
        pill.layer?.borderWidth = 1
        pill.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        container.addSubview(pill)

        let itemH: CGFloat = 24
        let itemY: CGFloat = (pillH - itemH) / 2

        // Single clear message: "Press  [ESC]  to close this overlay"
        let pressLabel = makeLabel("Press", size: 13, alpha: 0.55)
        pressLabel.frame = NSRect(x: 18, y: itemY + 1, width: 38, height: itemH)
        pill.addSubview(pressLabel)

        let escCap = makeKeycap("ESC", width: 40)
        escCap.frame.origin = NSPoint(x: 60, y: itemY)
        pill.addSubview(escCap)

        let closeLabel = makeLabel("to close this overlay", size: 13, alpha: 0.55)
        closeLabel.frame = NSRect(x: 106, y: itemY + 1, width: 155, height: itemH)
        pill.addSubview(closeLabel)

        // ✕ close button — clickable, right side
        let xSize: CGFloat = 28
        let xButton = NSButton(frame: NSRect(
            x: pillW - xSize - 7,
            y: (pillH - xSize) / 2,
            width: xSize, height: xSize
        ))
        xButton.bezelStyle = .regularSquare
        xButton.isBordered = false
        xButton.wantsLayer = true
        xButton.layer?.cornerRadius = xSize / 2
        xButton.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.3, alpha: 0.25).cgColor
        xButton.layer?.borderWidth = 1
        xButton.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.3, alpha: 0.5).cgColor
        let xAttr = NSAttributedString(string: "✕", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.9),
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }(),
        ])
        xButton.attributedTitle = xAttr
        xButton.target = self
        xButton.action = #selector(dismissClicked)
        pill.addSubview(xButton)
    }

    // MARK: - UI helpers

    private func makeKeycap(_ text: String, width: CGFloat) -> NSView {
        let h: CGFloat = 22
        let cap = NSView(frame: NSRect(x: 0, y: 0, width: width, height: h))
        cap.wantsLayer = true
        cap.layer?.cornerRadius = 5
        cap.layer?.borderWidth = 1.5
        cap.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.35).cgColor
        cap.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.07).cgColor

        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 0, y: 1, width: width, height: h - 1)
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.85)
        label.alignment = .center
        cap.addSubview(label)
        return cap
    }

    private func makeLabel(_ text: String, size: CGFloat, alpha: CGFloat, weight: NSFont.Weight = .medium) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor(calibratedWhite: 1.0, alpha: alpha)
        return label
    }

    @objc private func dismissClicked() {
        onDismiss?()
    }

    // MARK: - Keyboard monitors

    private func installKeyboardMonitors() {
        // Local monitor — when cute-hud has focus (rare, but possible)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true { return nil }
            return event
        }

        // Global monitor — when other apps have focus (the normal case)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    private func removeKeyboardMonitors() {
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let isEscape = event.keyCode == 53

        // Cmd+Shift+Escape — force quit
        if isEscape && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
            return true
        }

        // Plain Escape — dismiss overlay (hide directly as fallback even if onDismiss isn't set)
        if isEscape && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let dismiss = self.onDismiss {
                    dismiss()
                } else {
                    self.hide()
                }
            }
            return true
        }

        return false
    }
}

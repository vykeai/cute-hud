import AppKit
import Foundation

/// Floating HUD panel that renders on every connected display.
class HUDPanel: NSObject, NSApplicationDelegate {

    struct PanelBundle {
        let panel: NSPanel
        let dotView: NSView
        let stateLabel: NSTextField
        let badgeContainer: NSView
        let badgeLabel: NSTextField
        let subtitleLabel: NSTextField
        let detailLabel: NSTextField
        let factAccentBar: NSView
        let factEmojiLabel: NSTextField
        let factCategoryLabel: NSTextField
        let factTextLabel: NSTextField
        let taskLabel: NSTextField
        let countdownLabel: NSTextField
        let effectView: NSVisualEffectView
    }

    private(set) var panels: [PanelBundle] = []
    private var countdownTimer: Timer?
    private var countdownEndDate: Date?
    private(set) var overlayVisible = false
    let blocking = BlockingOverlay()
    private var wonderTimer: Timer?
    private var wonderFacts: [[String: String]] = []
    private var wonderIndex = 0
    private var lastExternalFact = false  // true if caller sent a fact — don't override

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanels()
        startStdinReader()
        loadWonderFacts()
        startWonderRotation()

        // Wire up safety dismiss — Escape or X button hides overlay + panel
        blocking.onDismiss = { [weak self] in
            guard let self else { return }
            self.blocking.hide()
            for b in self.panels { b.panel.level = .floating }
            self.hidePanel()
            emit(["event": "dismissed"])
        }

        emit(["event": "ready"])
    }

    // MARK: - Layout

    func setupPanels() {
        panels.removeAll()
        let W = HUD.panelWidth
        let H = HUD.panelHeight

        for screen in NSScreen.screens {
            let sf = screen.frame
            let frame = NSRect(x: sf.midX - W/2, y: sf.maxY - H - 12, width: W, height: H)

            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.appearance = NSAppearance(named: .darkAqua)
            panel.hasShadow = true
            panel.isMovableByWindowBackground = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0.0

            let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: W, height: H))
            bg.material = .hudWindow
            bg.blendingMode = .withinWindow
            bg.state = .active
            bg.appearance = NSAppearance(named: .darkAqua)
            bg.wantsLayer = true
            bg.layer?.cornerRadius = HUD.corner
            bg.layer?.masksToBounds = true
            bg.layer?.borderWidth = 1
            bg.layer?.borderColor = HUD.borderColor.cgColor
            bg.layer?.backgroundColor = HUD.bgColor.cgColor
            panel.contentView = bg

            // Top-edge sheen
            let sheen = NSView(frame: NSRect(x: HUD.insetX, y: H - 2, width: W - HUD.insetX*2, height: 1))
            sheen.wantsLayer = true
            sheen.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: HUD.sheenAlpha).cgColor
            bg.addSubview(sheen)

            // ── Row 1: dot + title + badge ──
            let row1Y = H - 34.0

            let dot = NSView(frame: NSRect(x: HUD.insetX, y: row1Y - 5, width: 10, height: 10))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 5
            dot.layer?.backgroundColor = NSColor.systemGray.cgColor
            bg.addSubview(dot)

            let title = NSTextField(labelWithString: "IDLE")
            title.frame = NSRect(x: HUD.insetX + 18, y: row1Y - 10, width: 380, height: 20)
            title.font = NSFont.systemFont(ofSize: 15, weight: .bold)
            title.textColor = HUD.textBright
            bg.addSubview(title)

            let badgeW: CGFloat = 130
            let badgeContainer = NSView(frame: NSRect(
                x: W - HUD.badgeInsetR - badgeW,
                y: row1Y - HUD.badgeH/2 + 1,
                width: badgeW, height: HUD.badgeH
            ))
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.cornerRadius = HUD.badgeH / 2
            badgeContainer.layer?.masksToBounds = true
            badgeContainer.layer?.backgroundColor = StateStyle.idle.badgeBg.cgColor
            badgeContainer.layer?.borderWidth = 1
            badgeContainer.layer?.borderColor = StateStyle.idle.badgeBorder.cgColor
            bg.addSubview(badgeContainer)

            let badgeLabel = NSTextField(labelWithString: "")
            badgeLabel.frame = NSRect(x: 0, y: 1, width: badgeW, height: HUD.badgeH - 1)
            badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
            badgeLabel.alignment = .center
            badgeLabel.textColor = StateStyle.idle.badgeText
            badgeContainer.addSubview(badgeLabel)

            // ── Row 2: action line ──
            let row2Y = H - 68.0
            let contentW = W - HUD.insetX - 110

            let subtitle = NSTextField(labelWithString: "")
            subtitle.frame = NSRect(x: HUD.insetX, y: row2Y, width: contentW, height: 20)
            subtitle.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            subtitle.textColor = HUD.textPrimary
            subtitle.lineBreakMode = .byTruncatingTail
            bg.addSubview(subtitle)

            // ── Row 3: detail line ──
            let row3Y = H - 90.0

            let detail = NSTextField(labelWithString: "")
            detail.frame = NSRect(x: HUD.insetX, y: row3Y, width: contentW, height: 16)
            detail.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            detail.textColor = HUD.textSecondary
            detail.lineBreakMode = .byTruncatingTail
            bg.addSubview(detail)

            // ── Row 4: lure fact card ──
            let factY: CGFloat = 36

            let accentBar = NSView(frame: NSRect(x: HUD.insetX, y: factY - 1, width: 4, height: 18))
            accentBar.wantsLayer = true
            accentBar.layer?.cornerRadius = 2
            accentBar.layer?.backgroundColor = NSColor(calibratedRed: 0.6, green: 0.45, blue: 0.75, alpha: 0.85).cgColor
            bg.addSubview(accentBar)

            let factEmoji = NSTextField(labelWithString: "")
            factEmoji.frame = NSRect(x: HUD.insetX + 12, y: factY, width: 20, height: 16)
            factEmoji.font = NSFont.systemFont(ofSize: 12)
            bg.addSubview(factEmoji)

            let factCategory = NSTextField(labelWithString: "")
            factCategory.frame = NSRect(x: HUD.insetX + 34, y: factY, width: 110, height: 16)
            factCategory.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            factCategory.textColor = HUD.textSecondary
            bg.addSubview(factCategory)

            let factText = NSTextField(labelWithString: "")
            factText.frame = NSRect(x: HUD.insetX + 148, y: factY, width: W - HUD.insetX - 178, height: 16)
            factText.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            factText.textColor = HUD.factPink
            factText.lineBreakMode = .byTruncatingTail
            bg.addSubview(factText)

            // ── Row 5: task line ──
            let task = NSTextField(labelWithString: "")
            task.frame = NSRect(x: HUD.insetX, y: 14, width: contentW, height: 14)
            task.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            task.textColor = HUD.textDim
            task.lineBreakMode = .byTruncatingTail
            bg.addSubview(task)

            // ── Countdown ──
            let countdown = NSTextField(labelWithString: "")
            countdown.frame = NSRect(x: W - 80, y: row2Y - 8, width: 52, height: 36)
            countdown.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold)
            countdown.alignment = .right
            countdown.textColor = StateStyle.warning.countdownColor
            bg.addSubview(countdown)

            panels.append(PanelBundle(
                panel: panel, dotView: dot, stateLabel: title,
                badgeContainer: badgeContainer, badgeLabel: badgeLabel,
                subtitleLabel: subtitle, detailLabel: detail,
                factAccentBar: accentBar, factEmojiLabel: factEmoji,
                factCategoryLabel: factCategory, factTextLabel: factText,
                taskLabel: task, countdownLabel: countdown, effectView: bg
            ))
        }
    }

    // MARK: - State updates

    func updateFromJSON(_ obj: [String: Any]) {
        // Support both "mode" (cute-hud native) and "state" (scouty compat)
        let mode = (obj["mode"] as? String) ?? (obj["state"] as? String) ?? "idle"
        let title         = obj["title"]         as? String ?? ""
        let badge         = obj["badge"]         as? String ?? ""
        let action        = obj["action"]        as? String ?? ""
        let detail        = obj["detail"]        as? String ?? ""
        let fact          = obj["fact"]          as? String ?? ""
        let factEmoji     = obj["fact_emoji"]    as? String ?? ""
        let factCategory  = obj["fact_category"] as? String ?? ""
        let task          = obj["task"]          as? String ?? ""
        let countdownVal  = obj["countdown"]     as? Int
        let isBlocking    = obj["blocking"]      as? Bool ?? false

        // Scouty compat fields
        let stageField    = obj["stage"]         as? String ?? ""
        let screenField   = obj["screen"]        as? String ?? ""
        let scenarioField = obj["scenario"]      as? String ?? ""
        let platformField = obj["platform"]      as? String ?? ""

        DispatchQueue.main.async { [self] in
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownEndDate = nil

            let style = StateStyle.forMode(mode)
            let shouldShow = (mode != "idle")

            // Blocking overlay
            if isBlocking && shouldShow {
                blocking.show()
                // Raise HUD panels above blocking overlay
                for b in panels { b.panel.level = .init(rawValue: NSWindow.Level.statusBar.rawValue + 1) }
            } else {
                blocking.hide()
                for b in panels { b.panel.level = .floating }
            }

            for b in panels {
                // Style
                b.dotView.layer?.backgroundColor = style.dotColor.cgColor
                b.stateLabel.stringValue = title.isEmpty ? style.defaultTitle : title.uppercased()
                b.badgeContainer.layer?.backgroundColor = style.badgeBg.cgColor
                b.badgeContainer.layer?.borderColor = style.badgeBorder.cgColor
                b.badgeLabel.textColor = style.badgeText
                b.countdownLabel.textColor = style.countdownColor

                // Badge text: use explicit badge, or derive from stage
                let badgeText = badge.isEmpty ? compactStage(stageField) : badge.uppercased()
                b.badgeLabel.stringValue = badgeText
                autoSizeBadge(b, text: badgeText)

                // Action / subtitle
                b.subtitleLabel.stringValue = action

                // Detail line
                if !detail.isEmpty {
                    b.detailLabel.stringValue = detail
                } else {
                    var parts: [String] = []
                    if !screenField.isEmpty   { parts.append("Screen: \(screenField)") }
                    if !scenarioField.isEmpty { parts.append("Scenario: \(scenarioField)") }
                    b.detailLabel.stringValue = parts.joined(separator: "  \u{00B7}  ")
                }

                // Task
                let prefix = platformField.isEmpty ? "" : platformPrefix(platformField)
                b.taskLabel.stringValue = "\(prefix)\(task)"

                // Fact card — caller-provided facts take priority over wonder rotation
                if !fact.isEmpty {
                    lastExternalFact = true
                    let catColor = categoryColor(factCategory)
                    b.factAccentBar.layer?.backgroundColor = catColor.withAlphaComponent(0.80).cgColor
                    b.factEmojiLabel.stringValue = factEmoji
                    let catStr = factCategory.uppercased()
                    let catAttr = NSMutableAttributedString(string: catStr, attributes: [
                        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                        .foregroundColor: catColor.withAlphaComponent(0.95),
                        .kern: 0.8 as NSNumber,
                    ])
                    b.factCategoryLabel.attributedStringValue = catAttr
                    let catWidth = catStr.isEmpty ? 0 : ceil(catAttr.size().width) + 10
                    let factTextX = HUD.insetX + 34 + catWidth
                    b.factTextLabel.frame = NSRect(
                        x: factTextX, y: b.factTextLabel.frame.origin.y,
                        width: HUD.panelWidth - factTextX - 30, height: 16
                    )
                    b.factTextLabel.stringValue = fact
                    setFactVisible(b, true)
                } else {
                    lastExternalFact = false
                    // Let wonder rotation handle it — don't hide if wonder is active
                    if wonderFacts.isEmpty {
                        setFactVisible(b, false)
                    }
                }
            }

            if shouldShow { showPanel() } else { hidePanel() }

            if let cd = countdownVal {
                beginCountdown(seconds: cd)
            } else {
                for b in panels { b.countdownLabel.stringValue = "" }
            }
        }
    }

    private func compactStage(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "" }
        let lower = cleaned.lowercased()
        if lower.contains("tap")                                    { return "TAPPING" }
        if lower.contains("swipe") || lower.contains("swiping")    { return "SWIPING" }
        if lower.contains("key") || lower.contains("keyboard")     { return "KEY PRESS" }
        if lower.contains("input") || lower.contains("text")       { return "TYPING" }
        if lower.contains("hold") || lower.contains("long")        { return "HOLDING" }
        if lower.contains("stabiliz")                               { return "STABILIZING" }
        if lower.contains("boot")                                   { return "BOOTING" }
        if lower.contains("foreground") || lower.contains("focus")  { return "FOCUSING" }
        if lower.contains("prepare") || lower.contains("preparing") { return "PREPARING" }
        if lower.contains("desktop")                                { return "DESKTOP" }
        return (cleaned.split(separator: " ").first.map(String.init) ?? cleaned).uppercased()
    }

    private func autoSizeBadge(_ b: PanelBundle, text: String) {
        if text.isEmpty {
            b.badgeContainer.isHidden = true
            return
        }
        b.badgeContainer.isHidden = false
        let textWidth = (text as NSString).size(
            withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)]
        ).width
        let newW = max(80, ceil(textWidth) + 28)
        b.badgeContainer.frame = NSRect(
            x: HUD.panelWidth - HUD.badgeInsetR - newW,
            y: b.badgeContainer.frame.origin.y,
            width: newW, height: HUD.badgeH
        )
        b.badgeLabel.frame = NSRect(x: 0, y: 1, width: newW, height: HUD.badgeH - 1)
    }

    private func setFactVisible(_ b: PanelBundle, _ visible: Bool) {
        b.factAccentBar.isHidden = !visible
        b.factEmojiLabel.isHidden = !visible
        b.factCategoryLabel.isHidden = !visible
        b.factTextLabel.isHidden = !visible
    }

    // MARK: - Countdown

    private func beginCountdown(seconds: Int) {
        countdownEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        renderCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.renderCountdown()
        }
    }

    private func renderCountdown() {
        guard let end = countdownEndDate else {
            for b in panels { b.countdownLabel.stringValue = "" }
            return
        }
        let remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
        for b in panels { b.countdownLabel.stringValue = "\(remaining)s" }
        if remaining <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    // MARK: - Visibility

    func hidePanel() {
        DispatchQueue.main.async { [self] in
            guard overlayVisible else { return }
            overlayVisible = false
            blocking.hide()
            for b in panels {
                b.panel.alphaValue = 0.0
                b.panel.orderOut(nil)
            }
            emit(["event": "hidden"])
        }
    }

    func showPanel() {
        DispatchQueue.main.async { [self] in
            guard !overlayVisible else { return }
            overlayVisible = true
            for b in panels {
                b.panel.alphaValue = 1.0
                b.panel.orderFrontRegardless()
            }
            emit(["event": "shown"])
        }
    }

    func playSound(name: String) {
        DispatchQueue.main.async {
            let soundName: String
            switch name {
            case "start":    soundName = "Tink"
            case "complete": soundName = "Glass"
            case "error":    soundName = "Basso"
            default:         soundName = "Tink"
            }
            NSSound(named: NSSound.Name(soundName))?.play()
        }
    }

    // MARK: - Wonder (lure fact rotation)

    private func loadWonderFacts() {
        // Load all facts from lure via Node in one shot, shuffle them
        let lurePath = NSHomeDirectory() + "/dev/lure/dist/index.js"
        guard FileManager.default.fileExists(atPath: lurePath) else { return }

        let script = """
        const l = require('\(lurePath)');
        const cats = l.populatedCategories();
        const all = [];
        for (const cat of cats) {
            const meta = l.getCategoryMeta(cat);
            const items = l.byCategory(cat);
            for (const item of items) {
                const text = typeof item === 'string' ? item : item.text;
                if (text) all.push({text, emoji: meta?.emoji || '🧠', category: cat});
            }
        }
        // Shuffle
        for (let i = all.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [all[i], all[j]] = [all[j], all[i]];
        }
        console.log(JSON.stringify(all));
        """

        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["node", "-e", script]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                wonderFacts = arr
            }
        } catch {
            // lure not available — no facts
        }
    }

    private func startWonderRotation() {
        guard !wonderFacts.isEmpty else { return }
        // Show first fact immediately
        showNextWonder()
        // Rotate every 10 seconds
        wonderTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.showNextWonder()
        }
    }

    private func showNextWonder() {
        guard !wonderFacts.isEmpty, overlayVisible, !lastExternalFact else { return }
        let fact = wonderFacts[wonderIndex % wonderFacts.count]
        wonderIndex += 1

        DispatchQueue.main.async { [self] in
            let text = fact["text"] ?? ""
            let emoji = fact["emoji"] ?? "🧠"
            let category = fact["category"] ?? ""

            for b in panels {
                let catColor = categoryColor(category)
                b.factAccentBar.layer?.backgroundColor = catColor.withAlphaComponent(0.80).cgColor
                b.factEmojiLabel.stringValue = emoji
                let catStr = category.uppercased()
                let catAttr = NSMutableAttributedString(string: catStr, attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: catColor.withAlphaComponent(0.95),
                    .kern: 0.8 as NSNumber,
                ])
                b.factCategoryLabel.attributedStringValue = catAttr
                let catWidth = catStr.isEmpty ? 0 : ceil(catAttr.size().width) + 10
                let factTextX = HUD.insetX + 34 + catWidth
                b.factTextLabel.frame = NSRect(
                    x: factTextX, y: b.factTextLabel.frame.origin.y,
                    width: HUD.panelWidth - factTextX - 30, height: 16
                )
                b.factTextLabel.stringValue = text
                setFactVisible(b, true)
            }
        }
    }

    // MARK: - Stdin reader

    func startStdinReader() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while let line = readLine() {
                guard let self else { break }
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let data = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                if obj["mode"] != nil || obj["state"] != nil {
                    self.updateFromJSON(obj)
                } else if let command = obj["command"] as? String {
                    switch command {
                    case "hide":  self.hidePanel()
                    case "show":  self.showPanel()
                    case "sound": if let n = obj["name"] as? String { self.playSound(name: n) }
                    default: break
                    }
                }
            }
            DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
        }
    }
}

// Helpers used in rendering
func platformPrefix(_ platform: String) -> String {
    switch platform.lowercased() {
    case "ios":     return "iOS \u{00B7} "
    case "android": return "\u{1F916} \u{00B7} "
    default:        return ""
    }
}

func emit(_ obj: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: obj),
       let str = String(data: data, encoding: .utf8) {
        print(str)
        fflush(stdout)
    }
}

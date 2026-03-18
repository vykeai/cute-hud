import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon, no menu bar
let delegate = HUDPanel()
app.delegate = delegate

signal(SIGINT)  { _ in DispatchQueue.main.async { NSApplication.shared.terminate(nil) } }
signal(SIGTERM) { _ in DispatchQueue.main.async { NSApplication.shared.terminate(nil) } }

app.run()

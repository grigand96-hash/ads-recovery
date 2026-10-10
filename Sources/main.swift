import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var window: NSWindow!
    var model: RecoveryModel!
    var stateItem = NSMenuItem(title: "Waiting for Safari", action: nil, keyEquivalent: "")
    var pauseItem = NSMenuItem(title: "Pause monitoring", action: #selector(togglePause), keyEquivalent: "")
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = RecoveryModel()
        status = NSStatusBar.system.statusItem(withLength: 28)
        if let path = Bundle.main.path(forResource: "StatusIcon", ofType: "png"), let icon = NSImage(contentsOfFile: path) {
            icon.size = NSSize(width: 18, height: 18); icon.isTemplate = true
            status.button?.image = icon
        } else { status.button?.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Ads Recovery") }
        status.button?.setAccessibilityLabel("Ads Recovery")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ads Recovery · PAD team", action: nil, keyEquivalent: ""))
        menu.addItem(stateItem); menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Ads Recovery…", action: #selector(showWindow), keyEquivalent: "")
        let ads = NSMenuItem(title: "Open Ads Manager", action: #selector(openAds), keyEquivalent: "")
        let agency = NSMenuItem(title: "About PAD team ↗", action: #selector(openAgency), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit Ads Recovery", action: #selector(quit), keyEquivalent: "q")
        for item in [open, ads, pauseItem, agency, quit] { item.target = self; menu.addItem(item) }
        status.menu = menu
        model.onUpdate = { [weak self] in
            guard let self else { return }
            self.stateItem.title = self.model.title
            self.status.button?.toolTip = "Ads Recovery: \(self.model.title)"
            self.pauseItem.title = self.model.monitoring ? "Pause monitoring" : "Resume monitoring"
        }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 680), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Ads Recovery"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedWhite: 245/255, alpha: 1)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: RootView(model: model))
        window.center()
        setupMenu()
        showWindow()
    }
    func setupMenu() {
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app)
        let submenu = NSMenu(); app.submenu = submenu
        let quit = NSMenuItem(title: "Quit Ads Recovery", action: #selector(quit), keyEquivalent: "q"); quit.target = self; submenu.addItem(quit)
        NSApp.mainMenu = main
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model.activate() }
    @objc func togglePause() { model.setMonitoring(!model.monitoring) }
    @objc func openAds() { model.openAdsManager() }
    @objc func openAgency() { NSWorkspace.shared.open(URL(string: "https://pad.team/")!) }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

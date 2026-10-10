import Cocoa
import Combine
import ApplicationServices

struct ActivityEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let title: String
}

final class RecoveryModel: ObservableObject {
    @Published var permitted = AXIsProcessTrusted()
    @Published var monitoring = true
    @Published var automatic = false
    @Published var title = "Waiting for Safari"
    @Published var detail = "Open Ads Manager in the active Safari tab."
    @Published var state: PageState = .outside
    @Published var lastCheck: Date?
    @Published var milliseconds = 0
    @Published var checks = 0
    @Published var attempts = 0
    @Published var working = false
    @Published var events: [ActivityEntry] = []
    @Published var notice: String?
    let diagnostics = Diagnostics()
    var onUpdate: (() -> Void)?
    private var timer: Timer?
    private var permissionTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let worker = DispatchQueue(label: "team.pad.adsrecovery.inspect", qos: .utility)
    private var gate = LoadingGate()
    private var lastSnapshot: Snapshot?
    private var inFlight = false
    private var generation = 0
    private var pendingRecovery: (url: String, pid: pid_t, date: Date, method: RecoveryMethod)?

    init() {
        gate.lastAttempt = UserDefaults.standard.double(forKey: "lastRecovery")
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.activate() })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.suspend() })
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.permitted != AXIsProcessTrusted() { self.activate() }
        }
        permissionTimer?.tolerance = 1
        activate()
    }
    func log(_ text: String) {
        guard events.first?.title != text else { return }
        events.insert(ActivityEntry(title: text), at: 0)
        if events.count > 6 { events.removeLast() }
    }
    func suspend() {
        timer?.invalidate(); timer = nil
        gate.reset(); generation += 1
    }
    func refreshPermission() {
        let allowed = AXIsProcessTrusted()
        if permitted != allowed { permitted = allowed; log(allowed ? "Interface access granted" : "Interface access disabled") }
    }
    func activate() {
        suspend(); refreshPermission()
        guard Installation.currentIsInstalled else {
            title = "Move Ads Recovery to Applications"
            detail = "Open the installed copy before setting up Safari access."
            onUpdate?(); return
        }
        guard permitted else {
            title = "Safari access needed"
            detail = "macOS has not granted access to this build. If Ads Recovery is already enabled in Settings, open the setup guide to repair its permission."
            onUpdate?(); return
        }
        guard monitoring else {
            title = "Monitoring paused"; detail = "The app is not checking Safari tabs."
            onUpdate?(); return
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Safari" else {
            title = "Waiting for Safari"; detail = "Checks resume when Safari becomes the active app."
            onUpdate?(); return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.scan() }
        timer?.tolerance = 1
        scan()
    }
    func setMonitoring(_ enabled: Bool) {
        monitoring = enabled
        log(enabled ? "Monitoring on" : "Monitoring paused")
        activate()
    }
    func setAutomatic(_ enabled: Bool) {
        automatic = enabled; gate.reset()
        log(enabled ? "Automatic recovery enabled" : "Automatic recovery disabled")
        onUpdate?()
    }
    func requestPermission() {
        guard Installation.currentIsInstalled else { notice = "Move Ads Recovery to Applications, then open that copy before allowing access."; return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    func openAdsManager() {
        guard let url = URL(string: "https://adsmanager.facebook.com/adsmanager/manage/campaigns"),
              let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { notice = "Safari was not found on this Mac."; return }
        NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if error != nil { DispatchQueue.main.async { self.notice = "Could not open Safari. Open Ads Manager manually." } }
        }
    }
    func inspectNow() {
        refreshPermission()
        guard permitted else { requestPermission(); return }
        guard let safari = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else { openAdsManager(); return }
        safari.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.scan() }
    }
    func recoverManually() {
        refreshPermission()
        guard permitted else { notice = "Allow interface access in macOS settings first."; return }
        guard let safari = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else { notice = "Open Ads Manager in Safari first."; return }
        safari.activate(options: [])
        log("Manual reload requested")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.scan(manual: true) }
    }
    func scan(manual: Bool = false) {
        guard !inFlight else {
            if manual { notice = "A check is already running. Try again in a few seconds." }
            return
        }
        guard AXIsProcessTrusted(), manual || monitoring else { refreshPermission(); return }
        inFlight = true; working = true
        let revision = generation
        worker.async {
            let snapshot = inspect()
            DispatchQueue.main.async {
                self.inFlight = false; self.working = false
                guard revision == self.generation else { return }
                self.process(snapshot, manual: manual)
            }
        }
    }
    private func process(_ s: Snapshot, manual: Bool) {
        diagnostics.record(.scan, state: s.state, milliseconds: s.milliseconds)
        checks += 1; lastCheck = Date(); milliseconds = s.milliseconds
        if let previous = lastSnapshot {
            if let a = previous.web, let b = s.web, !CFEqual(a, b) { gate.reset() }
            if let a = previous.window, let b = s.window, !CFEqual(a, b) { gate.reset() }
        }
        let changed = state != s.state
        lastSnapshot = s; state = s.state
        switch s.state {
        case .outside:
            title = "Waiting for Ads Manager"; detail = "Only the active Ads Manager tab is checked."
        case .loading:
            title = "Ads Manager is still loading"; detail = "Watching the initial loading screen and allowing 60 seconds."
        case .interfaceReady:
            title = "Ads Manager interface is open"; detail = "A table was found. The app does not check whether all campaign data has loaded."
        case .unsafe:
            title = "Waiting for a safe moment"; detail = "An input field or dialog is visible. The page will not be reloaded now."
        case .unknown:
            title = "Check the page"; detail = "The page state is unclear. Automatic reload is disabled for this check."
        }
        if changed && s.state != .outside { log(title) }
        if let pending = pendingRecovery {
            if pending.url == s.url && pending.pid == s.pid && s.state == .interfaceReady {
                diagnostics.record(.interfaceAppeared, state: s.state, method: pending.method, milliseconds: Int(Date().timeIntervalSince(pending.date) * 1000))
                log("Ads Manager interface appeared after reload")
                pendingRecovery = nil
            } else if Date().timeIntervalSince(pending.date) > 90 {
                diagnostics.record(.outcomeUnknown, state: s.state, method: pending.method)
                log("Reload result could not be confirmed")
                pendingRecovery = nil
            }
        }
        onUpdate?()
        let due = gate.observe(s.state, key: "\(s.pid):\(s.url)", now: Date.timeIntervalSinceReferenceDate)
        guard (automatic && monitoring && due) || (manual && [.interfaceReady, .loading].contains(s.state)) else {
            if manual { diagnostics.record(.reloadCancelled, state: s.state, method: .manual); notice = "Reload cancelled: open Ads Manager, finish editing, and close any dialogs." }
            return
        }
        if !manual {
            let idle = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel].map {
                CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
            }.min() ?? 0
            guard idle >= 10 else { return }
        }
        inFlight = true; working = true
        let revision = generation
        worker.async {
            let fresh = inspect()
            DispatchQueue.main.async {
                self.inFlight = false; self.working = false
                guard revision == self.generation,
                      manual || (self.monitoring && self.automatic), AXIsProcessTrusted(),
                      fresh.pid == s.pid, fresh.url == s.url,
                      let w = s.window, let w2 = fresh.window, CFEqual(w, w2),
                      let web = s.web, let web2 = fresh.web, CFEqual(web, web2),
                      fresh.state == s.state,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == s.pid else {
                    self.diagnostics.record(.reloadCancelled, state: fresh.state, method: manual ? .manual : .automatic)
                    self.log("Reload cancelled: the tab state changed")
                    return
                }
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 15, keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: 15, keyDown: false) else { return }
                down.flags = [.maskCommand, .maskAlternate]; up.flags = [.maskCommand, .maskAlternate]
                down.postToPid(s.pid); up.postToPid(s.pid)
                self.attempts += 1
                self.pendingRecovery = (s.url, s.pid, Date(), manual ? .manual : .automatic)
                self.diagnostics.record(.reloadSent, state: s.state, method: manual ? .manual : .automatic)
                self.gate.attempted(now: Date.timeIntervalSinceReferenceDate)
                UserDefaults.standard.set(self.gate.lastAttempt, forKey: "lastRecovery")
                self.title = "Reloading Ads Manager"
                self.detail = "Reload from origin requested. Waiting for the interface."
                self.log(manual ? "Manual reload sent" : "Automatic reload sent")
                self.onUpdate?()
            }
        }
    }
}

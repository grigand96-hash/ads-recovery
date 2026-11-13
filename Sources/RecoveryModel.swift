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
    @Published private(set) var manualRecoveryInProgress = false
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
        guard !manualRecoveryInProgress else { return }
        refreshPermission()
        guard permitted else { notice = "Allow interface access in macOS settings first."; return }
        guard let safari = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari")
            .first(where: { $0.processIdentifier > 0 }) else { notice = "Open Ads Manager in Safari first."; return }
        manualRecoveryInProgress = true
        title = "Checking Safari before reload"
        detail = "Keep the Ads Manager tab selected while we check it."
        log("Manual reload requested")
        onUpdate?()
        safari.activate(options: [])
        let pid = safari.processIdentifier
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.waitForSafari(pid: pid, deadline: deadline)
        }
    }

    private func waitForSafari(pid: pid_t, deadline: TimeInterval) {
        let active = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        if active && !inFlight {
            scan(manual: true)
        } else if ProcessInfo.processInfo.systemUptime < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForSafari(pid: pid, deadline: deadline)
            }
        } else {
            cancelManualReload(active ? "The Safari check timed out. Try again." : "Switch to the Ads Manager tab in Safari and try again.")
        }
    }

    private func cancelManualReload(_ reason: String) {
        manualRecoveryInProgress = false
        title = "Reload cancelled"
        detail = reason
        log("Reload cancelled. \(reason)")
        onUpdate?()
    }

    private func scan(manual: Bool = false) {
        guard !inFlight, manual || (monitoring && !manualRecoveryInProgress) else { return }
        guard AXIsProcessTrusted() else {
            refreshPermission()
            if manual { cancelManualReload("Allow interface access in macOS settings, then try again.") }
            return
        }
        inFlight = true
        let revision = generation
        worker.async {
            let snapshot = inspect()
            DispatchQueue.main.async {
                self.inFlight = false
                guard revision == self.generation else {
                    if manual { self.cancelManualReload("The Safari check was interrupted. Select Ads Manager and try again.") }
                    return
                }
                if !manual && self.manualRecoveryInProgress { return }
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
            title = "Ads Manager is still loading"; detail = "Automatic recovery waits for 60 seconds of loading."
        case .blank:
            title = "Ads Manager is blank"
            detail = "Use Refresh Current Tab to reload Ads Manager from the server."
        case .interfaceReady:
            title = "Ads Manager interface is open"; detail = "A table was found. The app does not check whether all campaign data has loaded."
        case .unsafe:
            title = "Waiting for a safe moment"; detail = "An input field or dialog is visible. The page will not be reloaded now."
        case .unknown:
            title = "Check the page"; detail = "The page state is unclear. Automatic reload is disabled for this check."
        }
        var awaitingInterface = false
        if let pending = pendingRecovery {
            let samePage = pending.url == s.url && pending.pid == s.pid
            if samePage && s.state == .interfaceReady {
                diagnostics.record(.interfaceAppeared, state: s.state, method: pending.method, milliseconds: Int(Date().timeIntervalSince(pending.date) * 1000))
                log("Ads Manager interface appeared after reload")
                pendingRecovery = nil
            } else if Date().timeIntervalSince(pending.date) > 90 {
                diagnostics.record(.outcomeUnknown, state: s.state, method: pending.method)
                log("Reload result could not be confirmed")
                pendingRecovery = nil
            } else if samePage {
                awaitingInterface = true
                title = "Waiting for Ads Manager after reload"
                detail = "Reload command sent to Safari. Keep this tab selected while Ads Manager loads."
            }
        }
        if changed && s.state != .outside && !awaitingInterface { log(title) }
        onUpdate?()
        let account = adsAccountID(in: s.url)
        let due = gate.observe(s.loadingForAutomaticRecovery, key: "\(s.pid):\(s.url)", account: account,
                               now: ProcessInfo.processInfo.systemUptime)
        let shouldReload = manual ? s.canReloadManually : (automatic && monitoring && due)
        guard shouldReload else {
            if manual {
                diagnostics.record(.reloadCancelled, state: s.state, method: .manual)
                switch s.state {
                case .unsafe: cancelManualReload("Finish editing and close any dialogs in Safari, then try again.")
                default: cancelManualReload("Select the Ads Manager tab in Safari and try again.")
                }
            }
            return
        }
        if !manual {
            let idle = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel].map {
                CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
            }.min() ?? 0
            guard idle >= 10 else { return }
        }
        inFlight = true
        let revision = generation
        worker.async {
            let fresh = inspect()
            DispatchQueue.main.async {
                self.inFlight = false
                guard revision == self.generation,
                      manual || (self.monitoring && self.automatic && !self.manualRecoveryInProgress), AXIsProcessTrusted(),
                      fresh.pid == s.pid, fresh.url == s.url,
                      let w = s.window, let w2 = fresh.window, CFEqual(w, w2),
                      let target = s.reloadTarget, let freshTarget = fresh.reloadTarget, CFEqual(target, freshTarget),
                      manual ? fresh.canReloadManually : fresh.loadingForAutomaticRecovery.isRecoverableLoading,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == s.pid else {
                    self.diagnostics.record(.reloadCancelled, state: fresh.state, method: manual ? .manual : .automatic)
                    if manual { self.cancelManualReload("The Safari tab or its state changed. Select Ads Manager and try again.") }
                    else if !self.manualRecoveryInProgress { self.log("Reload cancelled: the tab state changed") }
                    return
                }
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 15, keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: 15, keyDown: false) else {
                    if manual { self.cancelManualReload("Could not send the reload command. Try again in Safari.") }
                    return
                }
                down.flags = [.maskCommand, .maskAlternate]; up.flags = [.maskCommand, .maskAlternate]
                down.postToPid(s.pid); up.postToPid(s.pid)
                self.attempts += 1
                if self.monitoring { self.pendingRecovery = (s.url, s.pid, Date(), manual ? .manual : .automatic) }
                self.diagnostics.record(.reloadSent, state: fresh.state, method: manual ? .manual : .automatic)
                self.gate.attempted(account: account, now: ProcessInfo.processInfo.systemUptime)
                if manual { self.manualRecoveryInProgress = false }
                self.title = "Reloading Ads Manager"
                self.detail = self.monitoring ? "Safari is reloading from the server. Waiting for the interface." : "Reload from the server requested in Safari."
                self.log(manual ? "Manual reload sent" : "Automatic reload sent")
                self.onUpdate?()
            }
        }
    }
}

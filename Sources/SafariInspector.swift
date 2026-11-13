import Cocoa
import ApplicationServices

func attribute(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, key as CFString, &value) == .success else { return nil }
    return value
}
func string(_ e: AXUIElement, _ key: String) -> String { attribute(e, key) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement]? {
    var value: CFTypeRef?
    switch AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &value) {
    case .success: return value as? [AXUIElement]
    case .noValue, .attributeUnsupported: return []
    default: return nil
    }
}
func element(_ e: AXUIElement, _ key: String) -> AXUIElement? {
    guard let v = attribute(e, key), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
    return (v as! AXUIElement)
}

struct Snapshot {
    var state: PageState = .unknown
    var url = ""
    var pid: pid_t = 0
    var window: AXUIElement?
    var web: AXUIElement?
    var addressField: AXUIElement?
    var nodes = 0
    var milliseconds = 0

    var canReloadManually: Bool {
        (web != nil || addressField != nil) && isAdsManager(url) && state != .outside && state != .unsafe
    }

    var reloadTarget: AXUIElement? { web ?? addressField }

    var loadingForAutomaticRecovery: PageState {
        state == .blank && !isAccountSwitch(url) ? .unknown : state
    }
}

// Read only the front Safari window. Never retain page text or account data in logs.
func inspect() -> Snapshot {
    var s = Snapshot()
    guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication,
          front.bundleIdentifier == "com.apple.Safari" else { s.state = .outside; return s }
    s.pid = front.processIdentifier
    guard s.pid > 0 else { return s }
    let app = AXUIElementCreateApplication(s.pid)
    AXUIElementSetMessagingTimeout(app, 0.25)
    let window = ["AXFocusedWindow", "AXMainWindow"].lazy
        .compactMap { element(app, $0) }
        .first { string($0, "AXRole") == "AXWindow" }
    guard let window else { return s }
    s.window = window
    if let sheets = attribute(window, "AXSheets") as? [AXUIElement], !sheets.isEmpty {
        s.state = .unsafe; return s
    }
    if let focus = element(app, "AXFocusedUIElement"),
       ["AXTextField", "AXTextArea", "AXComboBox"].contains(string(focus, "AXRole")) {
        s.state = .unsafe; return s
    }
    let start = ProcessInfo.processInfo.systemUptime
    var chrome = [window], scanned = 0
    while scanned < chrome.count, scanned < 150, ProcessInfo.processInfo.systemUptime - start < 1 {
        let e = chrome[scanned]
        scanned += 1
        let role = string(e, "AXRole")
        if ["AXSheet", "AXDialog", "AXAlert"].contains(role) { s.state = .unsafe; return s }
        if role == "AXWebArea" {
            if let value = attribute(e, "AXURL") {
                s.url = (value as? URL)?.absoluteString ?? (value as? String ?? "")
            }
            if !s.url.isEmpty { s.web = e; break }
            continue
        }
        if role == "AXTextField",
           string(e, "AXIdentifier") == "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD",
           attribute(e, "AXFocused") as? Bool == false,
           s.addressField == nil {
            let address = string(e, "AXValue")
            if isAdsManager(address) { s.addressField = e }
        }
        if let descendants = children(e) { chrome.append(contentsOf: descendants.prefix(60)) }
    }
    guard let web = s.web, !s.url.isEmpty else {
        if let address = s.addressField {
            s.url = string(address, "AXValue")
            s.web = nil
            s.state = isAdsManager(s.url) ? .unknown : .outside
        }
        return s
    }
    guard isAdsManager(s.url) else { s.state = .outside; return s }
    let accountSwitch = isAccountSwitch(s.url)
    let contentStart = ProcessInfo.processInfo.systemUptime
    var queue = [web], cursor = 0
    var loading = false, controls = false, table = false, unsafe = false, truncated = false
    while cursor < queue.count && cursor < 240 && ProcessInfo.processInfo.systemUptime - contentStart < 0.7 {
        let e = queue[cursor]; cursor += 1
        let role = string(e, "AXRole")
        if ["AXTable", "AXGrid", "AXOutline"].contains(role) { table = true; continue }
        if ["AXDialog", "AXSheet", "AXAlert"].contains(role) { s.state = .unsafe; return s }
        if ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) { unsafe = true }
        if ["AXButton", "AXCheckBox", "AXPopUpButton"].contains(role) { controls = true }
        if role == "AXStaticText" || role == "AXHeading" {
            let parts = [string(e, "AXValue"), string(e, "AXTitle"), string(e, "AXDescription")]
            loading = loading || parts.contains { isLoadingLabel($0, accountSwitch: accountSwitch) }
        }
        guard !role.isEmpty, let descendants = children(e) else { truncated = true; continue }
        if descendants.count > 60 { truncated = true }
        queue.append(contentsOf: descendants.prefix(60))
    }
    s.nodes = cursor
    s.milliseconds = Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
    let complete = cursor == queue.count && !truncated
    if table { s.state = .interfaceReady }
    else if unsafe { s.state = .unsafe }
    else if complete && loading && !controls { s.state = .loading }
    else if complete && cursor == 1 { s.state = .blank }
    // Automatic recovery requires a complete scan.
    return s
}

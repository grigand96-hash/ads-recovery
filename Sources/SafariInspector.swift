import Cocoa
import ApplicationServices

func attribute(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, key as CFString, &value) == .success else { return nil }
    return value
}
func string(_ e: AXUIElement, _ key: String) -> String { attribute(e, key) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { attribute(e, "AXChildren") as? [AXUIElement] ?? [] }
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
    var nodes = 0
    var milliseconds = 0
}

// Read only the front Safari window. Never retain page text or account data in logs.
func inspect() -> Snapshot {
    var s = Snapshot()
    guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication,
          front.bundleIdentifier == "com.apple.Safari" else { s.state = .outside; return s }
    s.pid = front.processIdentifier
    let app = AXUIElementCreateApplication(s.pid)
    AXUIElementSetMessagingTimeout(app, 0.15)
    guard let window = element(app, "AXFocusedWindow") else { return s }
    s.window = window
    let start = ProcessInfo.processInfo.systemUptime
    var queue = [window], cursor = 0
    while cursor < queue.count && cursor < 100 && ProcessInfo.processInfo.systemUptime - start < 0.7 {
        let e = queue[cursor]; cursor += 1
        let role = string(e, "AXRole")
        if role == "AXWebArea" { s.web = e; break }
        if role == "AXSheet" || role == "AXDialog" { s.state = .unsafe; return s }
        queue.append(contentsOf: children(e).prefix(60))
    }
    guard let web = s.web else { return s }
    if let u = attribute(web, "AXURL") as? URL { s.url = u.absoluteString }
    else { s.url = string(web, "AXURL") }
    guard isAdsManager(s.url) else { s.state = .outside; return s }
    if let focus = element(app, "AXFocusedUIElement"),
       ["AXTextField", "AXTextArea", "AXComboBox"].contains(string(focus, "AXRole")) {
        s.state = .unsafe; return s
    }
    queue = [web]; cursor = 0
    var loading = false, controls = false, table = false, unsafe = false, truncated = false
    while cursor < queue.count && cursor < 240 && ProcessInfo.processInfo.systemUptime - start < 0.7 {
        let e = queue[cursor]; cursor += 1
        let role = string(e, "AXRole")
        if ["AXTable", "AXGrid", "AXOutline"].contains(role) { table = true; break }
        if ["AXTextField", "AXTextArea", "AXComboBox", "AXDialog", "AXSheet"].contains(role) { unsafe = true }
        if ["AXButton", "AXCheckBox", "AXPopUpButton"].contains(role) { controls = true }
        if role == "AXStaticText" || role == "AXHeading" {
            let parts = [string(e, "AXValue"), string(e, "AXTitle"), string(e, "AXDescription")]
            loading = loading || parts.contains(where: isLoadingLabel)
        }
        let descendants = children(e)
        if descendants.count > 60 { truncated = true }
        queue.append(contentsOf: descendants.prefix(60))
    }
    s.nodes = cursor
    s.milliseconds = Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
    let complete = cursor == queue.count && !truncated
    if table { s.state = .interfaceReady }
    else if unsafe { s.state = .unsafe }
    else if complete && loading && !controls { s.state = .loading }
    // An incomplete accessibility scan must never authorize recovery.
    return s
}

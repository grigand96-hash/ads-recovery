import Foundation

enum PageState: String {
    case outside, unknown, loading, blank, interfaceReady, unsafe

    var isRecoverableLoading: Bool { self == .loading || self == .blank }
}

func isAdsManager(_ text: String) -> Bool {
    guard let u = URL(string: text), u.scheme == "https",
          ["adsmanager.facebook.com", "business.facebook.com", "www.facebook.com"].contains(u.host ?? "") else { return false }
    return u.path == "/adsmanager" || u.path.hasPrefix("/adsmanager/")
}

// Meta renders the same loading label with a period or an ellipsis.
// Match the entire label so unrelated text cannot authorize a reload.
func isLoadingLabel(_ text: String, accountSwitch: Bool = false) -> Bool {
    let label = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    if accountSwitch && ["Launching Ads Manager...", "Launching Ads Manager…"].contains(label) {
        return true
    }
    return ["Loading your ad account", "Loading your ad account.",
            "Loading your ad account...", "Loading your ad account…"].contains(label)
}

func adsAccountID(in url: String) -> String? {
    guard isAdsManager(url),
          let account = URLComponents(string: url)?.queryItems?.first(where: { $0.name == "act" })?.value,
          !account.isEmpty, account.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
    return account
}

func isAccountSwitch(_ url: String) -> Bool {
    guard adsAccountID(in: url) != nil, let components = URLComponents(string: url),
          ["/adsmanager/manage/campaigns", "/adsmanager/manage/adsets", "/adsmanager/manage/ads"].contains(components.path) else { return false }
    return components.queryItems?.contains {
        $0.name == "nav_entry_point" && $0.value == "am_global_scope_selector"
    } == true
}

struct LoadingGate {
    private var identity: String?
    private var started: TimeInterval?
    private var previous: TimeInterval?
    private var samples = 0
    // The empty key covers Ads Manager URLs without an account ID.
    private var attempts: [String: TimeInterval] = [:]

    mutating func reset() { identity = nil; started = nil; previous = nil; samples = 0 }
    mutating func observe(_ state: PageState, key: String, account: String?, now: TimeInterval) -> Bool {
        guard state.isRecoverableLoading else { reset(); return false }
        if identity != key || previous.map({ !(0...12).contains(now - $0) }) != false {
            reset(); identity = key; started = now
        }
        previous = now; samples += 1
        let coolingDown = attempts[account ?? ""].map { now - $0 < 1800 } ?? false
        return samples >= 4 && now - (started ?? now) >= 60 && !coolingDown
    }
    mutating func attempted(account: String?, now: TimeInterval) {
        attempts = attempts.filter { now - $0.value < 1800 }
        attempts[account ?? ""] = now
        reset()
    }
}

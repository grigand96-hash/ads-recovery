import Foundation

enum PageState: String { case outside, unknown, loading, interfaceReady, unsafe }

func isAdsManager(_ text: String) -> Bool {
    guard let u = URL(string: text), u.scheme == "https",
          ["adsmanager.facebook.com", "business.facebook.com", "www.facebook.com"].contains(u.host ?? "") else { return false }
    return u.path == "/adsmanager" || u.path.hasPrefix("/adsmanager/")
}

// Meta renders the same loading label with a period or an ellipsis.
// Match the entire label so unrelated text cannot authorize a reload.
func isLoadingLabel(_ text: String) -> Bool {
    let label = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    return ["Loading your ad account", "Loading your ad account.",
            "Loading your ad account...", "Loading your ad account…"].contains(label)
}

struct LoadingGate {
    var identity: String?
    var started: TimeInterval?
    var previous: TimeInterval?
    var samples = 0
    var lastAttempt: TimeInterval = 0
    mutating func reset() { identity = nil; started = nil; previous = nil; samples = 0 }
    mutating func observe(_ state: PageState, key: String, now: TimeInterval) -> Bool {
        guard state == .loading else { reset(); return false }
        if identity != key || previous == nil || now - previous! > 12 || now < previous! {
            reset(); identity = key; started = now
        }
        previous = now; samples += 1
        return samples >= 4 && now - (started ?? now) >= 60 && now - lastAttempt >= 1800
    }
    mutating func attempted(now: TimeInterval) { lastAttempt = now; reset() }
}

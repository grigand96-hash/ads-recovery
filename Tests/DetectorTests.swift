import Foundation

@main struct Tests {
    static func main() {
        assert(isAdsManager("https://adsmanager.facebook.com/adsmanager/manage/campaigns?act=example"))
        for url in ["http://adsmanager.facebook.com/adsmanager/", "https://adsmanager.facebook.com.evil.test/adsmanager/", "https://facebook.com/", "https://www.facebook.com/adsmanager-spoof"] { assert(!isAdsManager(url)) }
        for label in ["Loading your ad account", "Loading your ad account.", "Loading your ad account...", "Loading your ad account…", " \nLoading  your ad\u{00a0}account. "] {
            assert(isLoadingLabel(label), "Expected loading label: \(label)")
        }
        for label in ["", "Loading your ad account failed", "Not Loading your ad account.", "Loading your ad account. Save changes?", "Loading your ad accounts."] {
            assert(!isLoadingLabel(label), "Unexpected loading label: \(label)")
        }
        let campaignURL = "https://adsmanager.facebook.com/adsmanager/manage/campaigns"
        let switchedURL = campaignURL + "?act=123&nav_entry_point=am_global_scope_selector&redirect_session_id=example"
        assert(isAccountSwitch(switchedURL))
        assert(adsAccountID(in: switchedURL) == "123")
        assert(!isAccountSwitch(campaignURL + "?act=123"))
        assert(!isAccountSwitch(campaignURL + "?nav_entry_point=am_global_scope_selector"))
        assert(!isAccountSwitch(campaignURL + "?act=123&nav_entry_point=other"))
        assert(!isAccountSwitch(switchedURL.replacingOccurrences(of: "/manage/campaigns", with: "/billing_hub")))
        assert(isLoadingLabel("Launching Ads Manager...", accountSwitch: true))
        assert(!isLoadingLabel("Launching Ads Manager..."))

        var g = LoadingGate()
        for t in stride(from: 0.0, through: 55, by: 5) { assert(!g.observe(.loading, key: "A", account: "123", now: t)) }
        assert(g.observe(.loading, key: "A", account: "123", now: 60))
        g.attempted(account: "123", now: 60)
        for t in stride(from: 65.0, through: 130, by: 5) {
            assert(!g.observe(.blank, key: "A-new-url", account: "123", now: t))
        }
        for t in stride(from: 135.0, through: 190, by: 5) {
            assert(!g.observe(t < 145 ? .loading : .blank, key: "B", account: "456", now: t))
        }
        assert(g.observe(.blank, key: "B", account: "456", now: 195))
        g.attempted(account: "456", now: 195)
        assert(!g.observe(.unsafe, key: "C", account: "789", now: 200))
        assert(!g.observe(.loading, key: "C", account: "789", now: 205))
        assert(!g.observe(.loading, key: "C", account: "789", now: 240)) // background/sleep gap
        assert(!g.observe(.interfaceReady, key: "C", account: "789", now: 245))
        assert(!g.observe(.unknown, key: "C", account: "789", now: 250))
        for t in stride(from: 1800.0, through: 1855, by: 5) {
            assert(!g.observe(.loading, key: "A", account: "123", now: t))
        }
        assert(g.observe(.loading, key: "A", account: "123", now: 1860))
        var buffer = DiagnosticBuffer()
        buffer.record(.scan, state: .loading)
        assert(buffer.events.isEmpty) // No collection before consent.
        buffer.setEnabled(true)
        for _ in 0..<70 { buffer.record(.scan, state: .loading, milliseconds: 999999) }
        assert(buffer.events.count == 50 && buffer.events[0].milliseconds == 120000)
        buffer.setEnabled(false)
        assert(buffer.events.isEmpty && buffer.take().isEmpty) // Revoke clears all queued data.
        buffer.record(.reloadSent, state: .loading, method: .manual)
        assert(buffer.events.isEmpty)
        buffer.setEnabled(true)
        assert(buffer.take().isEmpty) // No pre-consent history on re-enable.
        buffer.record(.interfaceAppeared, state: .interfaceReady, method: .manual)
        buffer.record(.scan, state: .blank)
        let encoded = try! JSONEncoder().encode(buffer.take())
        let object = try! JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
        assert(Set(object[0].keys) == Set(["kind", "state", "method", "milliseconds"]))
        assert(object[1]["state"] as? String == "unknown")
        assert(buffer.events.isEmpty)
        print("PASS: diagnostic consent, revocation, bounded queue, and closed event schema")
        print("PASS: host restrictions, 60-second threshold, cooldown, navigation, unsafe states and observation gaps")
    }
}

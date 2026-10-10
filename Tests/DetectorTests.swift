import Foundation

@main struct Tests {
    static func main() {
        assert(isAdsManager("https://adsmanager.facebook.com/adsmanager/manage/campaigns?act=example"))
        for url in ["http://adsmanager.facebook.com/adsmanager/", "https://adsmanager.facebook.com.evil.test/adsmanager/", "https://facebook.com/", "https://www.facebook.com/adsmanager-spoof"] { assert(!isAdsManager(url)) }
        var g = LoadingGate()
        for t in stride(from: 10000.0, through: 10055, by: 5) { assert(!g.observe(.loading, key: "A", now: t)) }
        assert(g.observe(.loading, key: "A", now: 10060))
        g.attempted(now: 10060)
        for t in stride(from: 10065.0, through: 10150, by: 5) { assert(!g.observe(.loading, key: "A", now: t)) }
        g.lastAttempt = 0
        assert(!g.observe(.loading, key: "B", now: 10155))
        assert(!g.observe(.unsafe, key: "B", now: 10160))
        assert(!g.observe(.loading, key: "B", now: 10165))
        assert(!g.observe(.loading, key: "B", now: 10200)) // background/sleep gap
        assert(!g.observe(.interfaceReady, key: "B", now: 10205))
        assert(!g.observe(.unknown, key: "B", now: 10210))
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
        let encoded = try! JSONEncoder().encode(buffer.take())
        let object = try! JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
        assert(Set(object[0].keys) == Set(["kind", "state", "method", "milliseconds"]))
        assert(buffer.events.isEmpty)
        print("PASS: diagnostic consent, revocation, bounded queue, and closed event schema")
        print("PASS: host restrictions, 60-second threshold, cooldown, navigation, unsafe states and observation gaps")
    }
}

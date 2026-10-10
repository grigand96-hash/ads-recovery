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
        print("PASS: host restrictions, 60-second threshold, cooldown, navigation, unsafe states and observation gaps")
    }
}

import Foundation
@main struct InstallationTests {
    static func main() {
        let home = URL(fileURLWithPath: "/Users/example")
        let cases: [(String, Bool)] = [
            ("/Applications/Ads Recovery.app", true),
            ("/Users/example/Applications/Ads Recovery.app", true),
            ("/Users/example/Downloads/Ads Recovery.app", false),
            ("/Volumes/Ads Recovery/Ads Recovery.app", false),
            ("/Applications-old/Ads Recovery.app", false),
            ("/Applications/Container/Ads Recovery.app", false)
        ]
        for (path, expected) in cases {
            precondition(Installation.isInstalled(URL(fileURLWithPath: path), home: home) == expected, path)
        }
        print("Installation location tests passed")
    }
}

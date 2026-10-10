import Foundation

enum Installation {
    static func isInstalled(_ app: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let parent = app.standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent().path
        return parent == "/Applications" || parent == home.appendingPathComponent("Applications").standardizedFileURL.resolvingSymlinksInPath().path
    }
    static var currentIsInstalled: Bool { isInstalled(Bundle.main.bundleURL) }
}

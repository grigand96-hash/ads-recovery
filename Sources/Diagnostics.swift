import Foundation
import Combine

// A closed schema: page content and free-form error messages cannot enter a report.
enum DiagnosticKind: String, Codable { case scan, reloadSent, reloadCancelled, interfaceAppeared, outcomeUnknown }
enum RecoveryMethod: String, Codable { case none, manual, automatic }
struct DiagnosticEvent: Codable {
    let kind: DiagnosticKind
    let state: String
    let method: RecoveryMethod
    let milliseconds: Int
}
struct DiagnosticReport: Encodable {
    let schema = 1
    let appVersion: String
    let macOS: String
    let architecture: String
    let events: [DiagnosticEvent]
}
struct DiagnosticBuffer {
    private(set) var enabled = false
    private(set) var events: [DiagnosticEvent] = []
    mutating func setEnabled(_ value: Bool) { enabled = value; if !value { events.removeAll() } }
    mutating func record(_ kind: DiagnosticKind, state: PageState, method: RecoveryMethod = .none, milliseconds: Int = 0) {
        guard enabled else { return }
        events.append(DiagnosticEvent(kind: kind, state: state.rawValue, method: method, milliseconds: min(120000, max(0, milliseconds))))
        if events.count > 50 { events.removeFirst(events.count - 50) }
    }
    mutating func take() -> [DiagnosticEvent] { defer { events.removeAll() }; return enabled ? events : [] }
}
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
final class Diagnostics: ObservableObject {
    static let endpoint = URL(string: "https://padteam.pro/ads-recovery/v1/events")!
    @Published private(set) var enabled: Bool
    @Published private(set) var status = "Off. No diagnostic data is sent."
    @Published private(set) var queued = 0
    private var buffer = DiagnosticBuffer()
    private var timer: Timer?
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var generation = 0
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.integer(forKey: "diagnosticsConsentVersion") == 1
        buffer.setEnabled(enabled)
        if enabled { start() }
    }
    deinit { timer?.invalidate(); session?.invalidateAndCancel() }
    func setEnabled(_ value: Bool) {
        generation += 1; task?.cancel(); task = nil
        timer?.invalidate(); timer = nil
        session?.invalidateAndCancel(); session = nil
        enabled = value; buffer.setEnabled(value); queued = 0
        defaults.set(value ? 1 : 0, forKey: "diagnosticsConsentVersion")
        status = value ? "On. Waiting for new diagnostic events." : "Off. Pending events cleared. Nothing new will be sent."
        if value { start() }
    }
    private func start() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = ["User-Agent": "AdsRecovery/1"]
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        status = "On. Only new diagnostic events will be sent."
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.flush() }
        timer?.tolerance = 10
    }
    func record(_ kind: DiagnosticKind, state: PageState, method: RecoveryMethod = .none, milliseconds: Int = 0) {
        buffer.record(kind, state: state, method: method, milliseconds: milliseconds); queued = buffer.events.count
    }
    private func report(_ events: [DiagnosticEvent]) -> DiagnosticReport {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return DiagnosticReport(appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0", macOS: "\(os.majorVersion).\(os.minorVersion)", architecture: architecture, events: events)
    }
    var preview: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(decoding: encoder.encode(report(buffer.events)), as: UTF8.self)) ?? "{}"
    }
    private func flush() {
        guard enabled, task == nil, !buffer.events.isEmpty, let session else { return }
        let events = buffer.take(); queued = 0
        guard let body = try? JSONEncoder().encode(report(events)) else { return }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let revision = generation
        task = session.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self, revision == self.generation, self.enabled else { return }
                self.task = nil
                let accepted = error == nil && (response as? HTTPURLResponse)?.statusCode == 204
                self.status = accepted ? "Last batch delivered to PAD team." : "Last batch could not be delivered and was discarded."
            }
        }
        task?.resume()
    }
}

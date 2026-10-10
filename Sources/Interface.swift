import SwiftUI
import AppKit

// Keep the property-wrapper implementation when building with Command Line Tools.
typealias ViewState<Value> = SwiftUI.State<Value>

enum Brand {
    static let paper = Color(red: 245/255, green: 245/255, blue: 245/255)
    static let ink = Color(red: 26/255, green: 26/255, blue: 26/255)
    static let muted = Color(red: 98/255, green: 98/255, blue: 98/255)
    static let line = Color(red: 218/255, green: 218/255, blue: 218/255)
    static let blue = Color(red: 47/255, green: 84/255, blue: 235/255)
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 16
    var interactive = false
    var tint: Color? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(tint ?? Color.white, in: RoundedRectangle(cornerRadius: radius))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular.tint(tint).interactive(interactive), in: RoundedRectangle(cornerRadius: radius))
            } else {
                fallback(content)
            }
            #else
            fallback(content)
            #endif
        }
    }
    private func fallback(_ content: Content) -> some View {
        content.background { RoundedRectangle(cornerRadius: radius).fill(tint ?? Color.clear).opacity(0.9) }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.7), lineWidth: 1).allowsHitTesting(false))
    }
}

struct ActionStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Brand.text(13, .medium))
            .padding(.horizontal, 18).frame(height: 40)
            .foregroundStyle(Brand.ink)
            .modifier(GlassSurface(radius: 20, interactive: true, tint: primary ? Brand.blue.opacity(0.18) : nil))
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
    }
}

struct AssetImage: View {
    let name: String
    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"), let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image).resizable().scaledToFit()
        }
    }
}

struct AgencyFooter: View {
    var body: some View {
        HStack(spacing: 12) {
            AssetImage(name: "PAD-mascot").frame(width: 43, height: 43).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Made by PAD team").font(Brand.text(12, .medium))
                Text("We help mobile apps grow.").font(Brand.text(11)).foregroundStyle(Brand.muted)
            }
            Spacer()
            Link(destination: URL(string: "https://pad.team/")!) {
                HStack(spacing: 7) { Text("About the agency"); Image(systemName: "arrow.up.right") }
                    .font(Brand.text(12, .medium)).foregroundStyle(Brand.ink)
            }.help("Open pad.team in your browser")
        }.padding(.horizontal, 18).padding(.vertical, 13)
            .modifier(GlassSurface(radius: 20)).padding(.horizontal, 16).padding(.bottom, 14)
    }
}

struct BrowserIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(Brand.line).frame(width: 6, height: 6) }
                Spacer()
                Text("Ads Manager · Safari").font(Brand.text(10)).foregroundStyle(Brand.muted)
                Spacer()
            }.padding(13).background(Color.white)
            Rectangle().fill(Brand.line).frame(height: 1)
            ZStack {
                VStack(alignment: .leading, spacing: 11) {
                    RoundedRectangle(cornerRadius: 3).fill(Brand.line).frame(width: 82, height: 8)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 9) {
                            RoundedRectangle(cornerRadius: 3).fill(Brand.line.opacity(0.7)).frame(width: 17, height: 17)
                            RoundedRectangle(cornerRadius: 3).fill(Brand.line.opacity(0.6)).frame(height: 6)
                        }
                    }
                }.padding(24).opacity(0.7)
                AssetImage(name: "AppIcon-128").frame(width: 86, height: 86)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
            }.frame(height: 173)
        }.background(Brand.paper).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line, lineWidth: 1))
            .rotationEffect(.degrees(-3))
            .accessibilityLabel("Illustration: restoring Ads Manager")
    }
}

struct HelpRow: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).font(.system(size: 17, weight: .regular)).foregroundStyle(Brand.blue).frame(width: 24, height: 25)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Brand.text(13, .medium))
                Text(detail).font(Brand.text(12)).foregroundStyle(Brand.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var model: RecoveryModel
    let finish: () -> Void
    @ViewState private var step = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 22) {
                ForEach(Array(["Welcome", "Access", "Ready"].enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 7) {
                        Text(index < step ? "✓" : "\(index + 1)").font(Brand.text(10, .medium))
                            .frame(width: 21, height: 21)
                            .background(index == step ? Brand.ink : Color.clear)
                            .foregroundStyle(index == step ? Color.white : Brand.muted)
                            .clipShape(Circle())
                        Text(name).font(Brand.text(12, index == step ? .medium : .regular)).foregroundStyle(index == step ? Brand.ink : Brand.muted)
                    }.accessibilityElement(children: .ignore).accessibilityLabel("Step \(index + 1): \(name)\(index == step ? ", current" : "")")
                }
            }.padding(.bottom, 30)
            ScrollView {
                Group {
                    if step == 0 { introduction }
                    else if step == 1 { permission }
                    else { ready }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }
            Spacer(minLength: 18)
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }.buttonStyle(.plain).font(Brand.text(13)).foregroundStyle(Brand.muted)
                } else {
                    Text("Runs locally on your Mac").font(Brand.text(11)).foregroundStyle(Brand.muted)
                }
                Spacer()
                if step == 1 && !model.permitted {
                    Button("Set up later") { step = 2 }.buttonStyle(.plain).font(Brand.text(12)).foregroundStyle(Brand.muted)
                    Button("Check access") { model.activate(); if model.permitted { step = 2 } }.buttonStyle(ActionStyle())
                } else {
                    Button(step == 2 ? "Get started" : "Continue") { if step == 2 { finish() } else { step += 1 } }
                        .buttonStyle(ActionStyle())
                }
            }
        }.padding(30)
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 27) {
            HStack(alignment: .center, spacing: 34) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("When Ads Manager\ngets stuck").font(Brand.text(33)).tracking(-0.9).lineSpacing(0).fixedSize(horizontal: false, vertical: true)
                    Text("Ads Recovery helps you reload a stuck Meta Ads Manager in Safari and get back to work.")
                        .font(Brand.text(14)).foregroundStyle(Brand.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                BrowserIllustration().frame(width: 227)
            }
            HelpRow(symbol: "macwindow", title: "Recognizes Ads Manager", detail: "Checks the active tab only while you are using Safari.")
            HelpRow(symbol: "arrow.clockwise", title: "Helps with a stuck loading screen", detail: "Reloads the page from origin. Other causes may need a different fix.")
        }
    }
    private var permission: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("One permission\nto work with Safari").font(Brand.text(33)).tracking(-0.9).fixedSize(horizontal: false, vertical: true)
            Text("The app needs to read window elements and send a reload command. macOS grants broad permission to control the interface for this.")
                .font(Brand.text(14)).foregroundStyle(Brand.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Image(systemName: model.permitted ? "checkmark.circle.fill" : "lock.shield").font(.system(size: 26)).foregroundStyle(Brand.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.permitted ? "Access granted" : "Device Control and Data Access").font(Brand.text(13, .medium))
                    Text(model.permitted ? "You can continue to the next step." : "Called Accessibility on older macOS versions.").font(Brand.text(12)).foregroundStyle(Brand.muted)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
            if !model.permitted {
                Button { model.requestPermission() } label: {
                    HStack { Text("Open macOS settings"); Image(systemName: "arrow.up.right") }
                }.buttonStyle(ActionStyle(primary: false))
                Text("Enable Ads Recovery in the app list, then return here.")
                    .font(Brand.text(12)).foregroundStyle(Brand.muted)
            }
            DisclosureGroup("Already enabled, but access is still missing?") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This beta uses an ad-hoc signature. macOS may keep permission for an older build, even when its switch is on. Remove only the old Ads Recovery entry with the minus button, then add this copy again using the plus button. Approve the macOS prompt and return here. Access is checked automatically.")
                    Button("Show this copy in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }.buttonStyle(.link)
                    Text("Keep one installed copy in Applications. A later update may need permission again.")
                }.font(Brand.text(12)).foregroundStyle(Brand.muted).lineSpacing(3).padding(.top, 8)
            }.font(Brand.text(12))
            Text("The app only works with Safari. Page content is never saved or sent. Optional diagnostics use only technical events, with your permission.")
                .font(Brand.text(12)).foregroundStyle(Brand.muted).lineSpacing(3)
        }
    }
    private var ready: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text("Back to your\ncampaigns").font(Brand.text(33)).tracking(-0.9).fixedSize(horizontal: false, vertical: true)
            HelpRow(symbol: "menubar.rectangle", title: "Ads Recovery stays in your menu bar", detail: "Close this window. Click the circular arrow icon whenever you need settings or a manual reload.")
            HelpRow(symbol: "hand.raised", title: "Start by observing", detail: "Automatic recovery is off. You can enable it separately when you are ready to try the experimental mode.")
            HelpRow(symbol: "clock", title: "Time between attempts", detail: "Automatic mode waits 60 seconds on the known loading screen and attempts recovery at most once every 30 minutes.")
            PrivacyView(diagnostics: model.diagnostics)
            Text("Only the English “Loading your ad account” screen is recognized. This cannot fix every Meta issue.")
                .font(Brand.text(12)).foregroundStyle(Brand.muted).lineSpacing(3)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var model: RecoveryModel
    let showSetup: () -> Void
    @ViewState private var confirmReload = false
    @ViewState private var confirmAuto = false
    @ViewState private var showDetails = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Circle().fill(model.permitted && model.monitoring ? Brand.blue : Brand.muted).frame(width: 6, height: 6)
                        Text(model.permitted ? (model.monitoring ? "Monitoring on" : "Paused") : "Setup needed")
                            .font(Brand.text(12)).foregroundStyle(Brand.muted)
                        Spacer()
                        Text("SAFARI / macOS").font(Brand.text(10, .medium)).tracking(0.7).foregroundStyle(Brand.muted)
                    }
                    Text(model.title).font(Brand.text(29)).tracking(-0.6).fixedSize(horizontal: false, vertical: true)
                    Text(model.detail).font(Brand.text(13)).foregroundStyle(Brand.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button(model.permitted ? "Open Ads Manager" : "Allow access") {
                        if model.permitted { model.openAdsManager() } else { model.requestPermission() }
                    }.buttonStyle(ActionStyle())
                    if model.permitted {
                        Button("Recover Ads Manager…") { confirmReload = true }.buttonStyle(ActionStyle(primary: false)).disabled(model.working)
                    } else {
                        Button("Check access") { model.activate() }.buttonStyle(ActionStyle(primary: false))
                    }
                }
                VStack(spacing: 0) {
                    setting(title: "Monitor Safari", subtitle: model.permitted ? "Checks only while Safari is the active app." : "Starts once macOS permission is granted.", value: Binding(get: { model.monitoring }, set: { model.setMonitoring($0) }))
                    Rectangle().fill(Brand.line).frame(height: 1).padding(.horizontal, 18)
                    setting(title: "Automatic recovery", subtitle: "Experimental · waits 60 seconds", value: Binding(get: { model.automatic }, set: { enabled in if enabled { confirmAuto = true } else { model.setAutomatic(false) } }))
                }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent activity").font(Brand.text(12, .medium))
                        Spacer()
                        if let date = model.lastCheck { Text("Checked at \(date.formatted(date: .omitted, time: .shortened))").font(Brand.text(11)).foregroundStyle(Brand.muted) }
                    }
                    if model.events.isEmpty {
                        Text("The first Safari check will appear here.").font(Brand.text(12)).foregroundStyle(Brand.muted)
                    } else {
                        ForEach(model.events.prefix(3)) { event in
                            HStack(alignment: .firstTextBaseline) {
                                Text(event.date.formatted(date: .omitted, time: .shortened)).monospacedDigit().foregroundStyle(Brand.muted).frame(width: 40, alignment: .leading)
                                Text(event.title).foregroundStyle(Brand.ink)
                                Spacer(minLength: 0)
                            }.font(Brand.text(12))
                        }
                    }
                }
                PrivacyView(diagnostics: model.diagnostics)
                DisclosureGroup("How it works and check details", isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The known loading screen is observed for 60 seconds. Input fields, dialogs, or an unknown state prevent a reload. A visible interface does not confirm that all campaign data has loaded.")
                        Text("This session: \(model.checks) checks, \(model.attempts) reload commands. Last check: \(model.milliseconds) ms.")
                        Text("Activity stays in memory until you quit. Only setup completion, diagnostic consent, and the last recovery time are saved. Automatic recovery is off at every launch.")
                        HStack(spacing: 18) {
                            Button("Check now") { model.inspectNow() }
                            Button("Show introduction again", action: showSetup)
                        }.buttonStyle(.link)
                    }.font(Brand.text(12)).foregroundStyle(Brand.muted).lineSpacing(3).padding(.top, 10)
                }.font(Brand.text(12)).tint(Brand.muted)
            }.padding(30)
        }
        .alert("Reload Ads Manager?", isPresented: $confirmReload) {
            Button("Cancel", role: .cancel) { }
            Button("Reload") { model.recoverManually() }
        } message: {
            Text("Save your ad edits first. The app will switch to Safari, check the active tab, and reload Ads Manager from origin.")
        }
        .alert("Enable automatic recovery?", isPresented: $confirmAuto) {
            Button("Not now", role: .cancel) { }
            Button("Enable") { model.setAutomatic(true) }
        } message: {
            Text("This mode is experimental. It recognizes only the English “Loading your ad account” screen, waits 60 seconds, and allows one attempt every 30 minutes. The full recovery sequence has not yet been verified on another real hang.")
        }
    }
    private func setting(title: String, subtitle: String, value: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Brand.text(13, .medium))
                Text(subtitle).font(Brand.text(11)).foregroundStyle(Brand.muted)
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).tint(Brand.blue)
                .accessibilityLabel(title).disabled(!model.permitted)
        }.padding(18)
    }
}

struct RootView: View {
    @ObservedObject var model: RecoveryModel
    @AppStorage("publicOnboardingV1Finished") private var finished = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AssetImage(name: "AppIcon-128").frame(width: 31, height: 31).accessibilityHidden(true)
                Text("Ads Recovery").font(Brand.text(14, .medium))
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0") BETA").font(Brand.text(9, .medium)).tracking(1).foregroundStyle(Brand.muted)
                    .padding(.horizontal, 7).padding(.vertical, 4).overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                Spacer()
                if finished {
                    Button("Setup guide") { finished = false }.buttonStyle(.link).font(Brand.text(12))
                }
                Text("by PAD team").font(Brand.text(12)).foregroundStyle(Brand.muted)
            }.padding(.horizontal, 18).padding(.vertical, 13)
                .modifier(GlassSurface(radius: 20)).padding(.horizontal, 16).padding(.top, 12)
            if finished { DashboardView(model: model, showSetup: { finished = false }) }
            else { OnboardingView(model: model, finish: { finished = true; model.activate() }) }
            AgencyFooter()
        }.frame(width: 720, height: 680).background {
            ZStack {
                Brand.paper
                Circle().fill(Brand.blue.opacity(0.07)).frame(width: 260, height: 260).blur(radius: 70).offset(x: 275, y: -300)
                Circle().fill(Color.pink.opacity(0.055)).frame(width: 190, height: 190).blur(radius: 60).offset(x: -290, y: 315)
            }.clipped()
        }.foregroundStyle(Brand.ink)
            .preferredColorScheme(.light)
            .alert("Ads Recovery", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
                Button("OK") { model.notice = nil }
            } message: { Text(model.notice ?? "") }
    }
}

struct PrivacyView: View {
    @ObservedObject var diagnostics: Diagnostics
    @ViewState private var expanded = false
    @ViewState private var consent = false
    @ViewState private var preview = false
    var body: some View {
        DisclosureGroup("Privacy & diagnostics", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recovery runs locally on your Mac. Optional diagnostics help PAD team understand which recovery attempts work.")
                Toggle("Share technical diagnostics with PAD team", isOn: Binding(get: { diagnostics.enabled }, set: { if $0 { consent = true } else { diagnostics.setEnabled(false) } }))
                    .toggleStyle(.switch).tint(Brand.blue)
                Text(diagnostics.status).foregroundStyle(Brand.muted)
                Text("Shared: app version, macOS version, processor type, check duration, page-state category, reload method, and outcome. No account IDs, URLs, ad content, page text, cookies, credentials, screenshots, or browsing history. No user or device identifier.")
                Text("Sent over HTTPS to padteam.pro, operated by PAD team. Daily totals are kept for up to 30 days. The server sees your IP during connection but this endpoint does not log it. Network providers may process connection metadata.")
                Text("Turning this off cancels pending sends and clears the in-memory queue. A request already received cannot be recalled. Previously received daily totals expire automatically and are not indexed by user or device.")
                Button("Preview pending data (\(diagnostics.queued) events)") { preview = true }.buttonStyle(.link)
            }.font(Brand.text(12)).lineSpacing(3).padding(.top, 10)
        }.font(Brand.text(12)).tint(Brand.muted)
        .alert("Share technical diagnostics?", isPresented: $consent) {
            Button("Keep local", role: .cancel) { }
            Button("Agree and enable") { diagnostics.setEnabled(true) }
        } message: {
            Text("New technical events will be sent to PAD team at padteam.pro: app and macOS versions, processor type, check timings, page-state categories, reload methods, and outcomes. No page content, account details, URLs, or persistent identifiers. Daily totals expire after 30 days. You can turn this off at any time. Recovery works without sharing.")
        }
        .sheet(isPresented: $preview) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pending diagnostic data").font(Brand.text(22))
                Text("This is the current queue. With sharing enabled, batches are sent about once a minute. Nothing is written to a local log file.").font(Brand.text(12))
                ScrollView { Text(diagnostics.preview).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Button("Done") { preview = false }.buttonStyle(ActionStyle())
            }.padding(24).frame(width: 570, height: 430)
        }
    }
}

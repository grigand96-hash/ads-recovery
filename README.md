# Ads Recovery

A small macOS menu bar app by [PAD team](https://pad.team/) for Meta Ads Manager in Safari. It recognizes the initial loading screen and can reload the page from origin.

**Experimental beta.** Manual reload and detection of the loaded interface were verified on a local Mac. Automatic recovery from a second real-world hang has not yet been verified. This is not a fix for every Meta or Safari issue, and it is not affiliated with Meta or Apple.

## What you get

- A three-step introduction in English, with an explanation of the macOS permission.
- A menu bar icon, current status, manual recovery, pause, and a short local activity history.
- Automatic recovery as an optional experimental mode, off at every launch.
- A native AppKit / SwiftUI interface using system fonts. No embedded browser or third-party runtime.

## Build

Requires macOS and Apple Command Line Tools or Xcode. The deployment target is macOS 14. Current live testing was on Apple Silicon with macOS 27.0.1 and Safari 27.0.1; older systems and Intel hardware still need testing.

```sh
bash Scripts/build.sh
```

The script runs the detector tests, generates the icons, compiles Apple Silicon and Intel slices, packages `build/Ads Recovery.app`, and produces `build/Ads-Recovery-macOS.zip` with `build/SHA256SUMS.txt`.

For an Apple Silicon-only development build:

```sh
ARCHS=arm64 bash Scripts/build.sh
```

No paid Apple Developer account is required for these builds. The app uses an **ad-hoc signature**, not an Apple Developer ID signature, and it is not notarized. A downloaded build may require explicit approval in macOS Privacy & Security. Managed Macs may disallow this. Never disable Gatekeeper globally to install this app. [Apple's explanation](https://support.apple.com/en-gb/102445).

## GitHub builds

The workflow runs on pushes to `main`, version tags, pull requests, and manual dispatch. It uploads a ZIP and checksum to the Actions run. It does not publish a GitHub Release, modify the repository, or require signing secrets. Downloaded-build installation still needs testing on a clean Mac.

## First run

1. Open the app and follow the introduction.
2. Allow Ads Recovery under **Privacy & Security → Device Control and Data Access**. Older macOS versions call this **Accessibility**. The introduction can also be skipped to inspect the app without granting access.
3. Open Ads Manager in Safari. The app checks only while Safari is the foreground app.
4. Use **Recover Ads Manager…** for a manual reload after saving edits. To pause all background checks, turn off **Monitor Safari** or choose pause from the menu bar.

Closing the window leaves the menu bar app running. Quit from its menu to stop it completely. Login-at-startup is not installed. Rebuilding an ad-hoc-signed app may invalidate its macOS permission; remove the old permission entry and add the new build if needed.

## How automatic recovery works

The detector currently supports only the English text **Loading your ad account** on an HTTPS Ads Manager URL at `adsmanager.facebook.com`, `business.facebook.com`, or `www.facebook.com`.

It requires 60 seconds of consecutive observations of that screen, a complete bounded accessibility scan with no form controls, and 10 seconds without recent typing, clicks, or scrolling. Before sending Option–Command–R, it checks the process, window, URL, page object, and state again. An automatic attempt is allowed at most once per 30 minutes across the app, including after restart.

Unknown states and incomplete scans do not authorize automatic reload. A detected table means the interface appeared; it does not prove the campaign data is complete. Sending a keyboard shortcut cannot atomically target a particular Safari tab, so a small tab-switch race remains. Treat automatic mode as experimental.

## Privacy

The macOS permission is broad; the app itself restricts inspection and control to Safari. It reads the foreground page URL to check its scope and temporarily reads interface elements on supported pages. It does not read browser cookies or credentials, send telemetry, or persist page URLs, account IDs, or page text.

The event list lives in memory and contains generic status messages only. UserDefaults stores onboarding completion and the time of the last recovery attempt. The agency link opens pad.team in the browser only when clicked; the website has its own privacy policy.

## Design

The light gray, ink, and blue palette follows [PAD team's website](https://pad.team/) and its tools section. The app uses the macOS system font rather than redistributing the website's Suisse Intl font. The application and menu icons are drawn from code in `Scripts/GenerateIcons.swift`.

Source code: MIT. PAD team branding and mascot are excluded from that license. The project contains no HAR files, browser profiles, or private account diagnostics.

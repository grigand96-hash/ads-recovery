# Changelog

## 0.1.2 · 2026-10-14

- Recognize the loading label with a final period or ellipsis, including the current “Loading your ad account.” screen. Version 0.1.1 treated this screen as unknown and refused recovery.
- Keep the existing complete-scan, unsafe-input, and reload timing checks.

This fixes detection of the loading screen. It does not establish that a reload will resolve every Safari loading failure.

## 0.1.1 · 2026-10-10

- A drag-and-drop DMG installer with an Applications shortcut and a visual installation guide.
- A location check explains how to move the app before requesting macOS access.
- Four setup steps: Install, Safari, Access, and Ready. Installed copies skip the move step.
- An illustrated permission screen with direct access to System Settings and live permission status.
- First-run help for missing entries and permissions left over from an older build.
- Setup opens again when the current copy needs access. The final step can open Ads Manager in Safari.

Recovery behavior and diagnostic consent are unchanged. Automatic recovery remains experimental. This beta is not notarized; macOS may require first-launch approval and renewed permission after updating.

## 0.1.0 · 2026-10-10

First public beta. Earlier local prototype numbers were not public releases.

- English native macOS interface in the PAD team style, with system fonts and three-step onboarding.
- Liquid Glass header, footer, and buttons on macOS 26+, with fallbacks for older systems and reduced transparency.
- App icon, menu bar icon, agency link, pause control, and local activity history.
- Manual recovery and optional experimental automatic recovery for the known English loading screen.
- Rechecks before reload; stale and truncated scans cannot authorize automatic recovery.
- Optional diagnostics with separate consent, revocation, and a pending-data preview.
- PAD team receiver with strict fields, daily aggregates, and 30-day retention.
- Universal Apple Silicon / Intel builds and GitHub Actions artifacts.

Automatic recovery remains experimental and off at startup. Diagnostics are off until the user agrees. A full automatic recovery on a repeated real hang and installation on a clean Mac still need testing.

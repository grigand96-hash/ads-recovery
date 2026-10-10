# Changelog

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

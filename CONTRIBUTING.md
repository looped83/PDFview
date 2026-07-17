# Contributing to PDF Viewer

Thanks for your interest in improving PDF Viewer. This project has a narrow,
deliberate scope — please read the principles below before proposing a change.

## Principles

1. **Native only.** Swift, SwiftUI, AppKit, PDFKit, Foundation. No WebViews,
   Electron, cross-platform UI frameworks, or third-party PDF rendering engines.
2. **No new dependencies without a strong reason.** The app currently has zero
   third-party runtime dependencies. Keep it that way unless a dependency provides
   something PDFKit/AppKit/Foundation genuinely cannot.
3. **Privacy by default.** No network access, no telemetry, no analytics, no crash
   reporting SDKs, no account system. If a change would require any of these,
   discuss it in an issue first.
4. **Performance matters.** This is meant to stay lightweight even with very large
   PDFs. Avoid unnecessary copies of PDF data, unnecessary SwiftUI re-renders, and
   any blocking work on the main thread.
5. **Small, focused changes.** Prefer a pull request that does one thing well over
   one that bundles refactors with feature work.

## Getting started

See the "Lokale Entwicklung" section of the [README](README.md) for how to
generate the Xcode project and run the app locally.

## Before opening a pull request

- Run the unit tests (`⌘U` in Xcode, or `xcodebuild test` — see README).
- Run `scripts/build-release.sh` to confirm a clean Release build still succeeds.
- If you touched PDFKit/AppKit bridging code (`PDFKitView.swift` in particular),
  manually verify scrolling, zooming, and page navigation stay smooth on a large
  (multi-hundred-page) PDF — this is exactly the kind of regression automated
  tests won't catch.
- If you changed entitlements, explain why in the pull request description, and
  update the "Entitlements" section of the README.

## Reporting bugs

Please include: macOS version, a description of the PDF that triggers the issue
(page count, whether it's scanned/text-based/password-protected — not the file
itself unless it's something you're comfortable sharing), and steps to reproduce.

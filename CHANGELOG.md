# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses date-based versioning during initial development.

## [Unreleased]

### Added

- Initial native macOS 26 PDF viewer built with SwiftUI, AppKit, and PDFKit.
- Document-based multi-window architecture via `DocumentGroup(viewing:)`.
- Opening PDFs via the Open panel, Finder double-click/"Open With", drag-and-drop
  (window and Dock icon), and macOS's native Recent Documents.
- Password-protected PDF support with a dedicated unlock screen.
- Single page, continuous single page, two-up, and continuous two-up display modes.
- Zoom controls: actual size (100%), fit page, fit width, free zoom in/out, with
  persistent clamping between 10% and 800%.
- Page navigation: first/previous/next/last, direct page-number entry, and
  browser-style back/forward history through visited pages.
- Sidebar with lazily-loaded, cached page thumbnails and a native outline
  (table of contents) view, each independently toggleable.
- Non-blocking, cancellable full-text search with match count, next/previous, and
  in-document highlighting, backed by PDFKit's asynchronous find API.
- Native text selection, copy, and link handling via PDFKit.
- Printing, "Save a Copy", and "Show in Finder", without ever modifying the
  original file.
- Per-file last-viewed-page and zoom restoration, stored locally (page number and
  zoom only — never document content).
- Full keyboard shortcut coverage (⌘O, ⌘W, ⌘F, ⌘P, ⌘+/⌘-/⌘0/⌘1/⌘2, ⌃⌘S, ⌘[ / ⌘]).
- Accessibility: VoiceOver labels, full keyboard navigation, native controls throughout.
- Unit tests (Swift Testing) and UI tests (XCTest/XCUITest) covering the core flows,
  backed by PDF fixtures generated at test time (no binary fixtures committed).
- Reproducible build, signing, notarization, and DMG-creation scripts under `scripts/`.

## [1.0.0] - Unreleased

Initial version under development. See "Offene Punkte" in the project README for
what remains before a first tagged release.

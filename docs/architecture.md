# Architecture

Short record of the decisions that shape this codebase, and why. For the file
layout itself, see the "Projektstruktur" section of the README.

## 1. `DocumentGroup(viewing:)`, not a hand-rolled window manager

SwiftUI's `DocumentGroup` (built on the same `NSDocumentController` machinery
AppKit document apps have always used) gives multi-window support, the native
Open panel, "Open Recent", Finder document-type association, and per-window
state isolation for free. The `viewing:` variant (as opposed to the editing
variant) is specifically for read-only document apps: it omits Save/Save As/Undo
menu commands automatically, which matches this app exactly — it's a viewer, and
the original file must never be modified by ordinary use.

## 2. `ReferenceFileDocument`, not `FileDocument`

`PDFKit.PDFDocument` is a class wrapping a potentially large in-memory
representation of the file. `FileDocument` (value-type document model) would
require SwiftUI to be able to reason about the document as a `Codable`-ish value;
`ReferenceFileDocument` instead hands SwiftUI a reference and lets it observe
changes via `ObservableObject`, so the PDF payload is never duplicated or
diffed as part of the SwiftUI update cycle.

## 3. File content vs. viewing state: two separate types

- `PDFFileDocument` (`Document/PDFFileDocument.swift`) owns *only* loading the
  file and detecting locked/corrupt PDFs. It is the `ReferenceFileDocument`
  SwiftUI holds onto.
- `PDFDocumentState` (`Document/PDFDocumentState.swift`) owns *everything about
  viewing it in one window*: current page, zoom, layout mode, sidebar, search,
  navigation history. It is created once per window (`@State` in
  `PDFViewerContainer`) and is not `Codable`/persisted — it's pure UI state.

This split means opening the same file in two windows never causes them to
fight over "the" current page or zoom level, and it means zoom/scroll/sidebar
changes never touch — or invalidate SwiftUI's view of — the (possibly large)
PDF payload itself.

## 4. `PDFKitView`: bridge once, diff on every update

`PDFView` (AppKit) is created exactly once in `makeNSView`. `updateNSView` never
recreates it — it diffs `PDFDocumentState` against the live view's current
properties and only writes what actually changed (`Coordinator.synchronize`).
Recreating the view on every SwiftUI state change was considered and rejected:
it would drop scroll position, discard PDFKit's internal render cache, and
reflow visible pages on every keystroke in the page-number field.

The same `Coordinator` also observes PDFKit's own notifications
(`PDFViewPageChanged`, `PDFViewScaleChanged`, `PDFViewDocumentChanged`) and
pushes changes back into `PDFDocumentState` — but only when the value actually
differs from what's already there, which is what prevents an update loop
between "state pushed to view" and "view notification pushed back to state".

## 5. Search: PDFKit's asynchronous find, not the synchronous one

`PDFSearchController` uses `PDFDocument.beginFindString(withOptions:)` /
`cancelFindString()`, which deliver matches incrementally via notifications,
instead of the synchronous `findString(...)`, which would block the calling
thread for as long as the search takes — unacceptable for a multi-thousand-page
document. Typing a new query cancels the in-flight search immediately.

## 6. Thumbnails: lazy, cached, never bulk-generated

`ThumbnailSidebar` renders rows inside a `LazyVStack`, so only thumbnails near
the visible scroll area are ever generated — opening a 2,000-page PDF does not
render 2,000 bitmaps. Generated thumbnails are cached in an `NSCache` (which
evicts under memory pressure on its own), so scrolling back to an
already-visited page is instant. Generation intentionally stays on the main
actor rather than a detached `Task`, because PDFKit's types are not `Sendable`
and cannot safely cross actor boundaries under Swift 6 strict concurrency;
`Task.yield()` plus per-row cancellation via `.task(id:)` keeps this from
blocking the UI for any meaningful stretch.

## 7. Menu commands via `FocusedValue`, not a global singleton

Multiple document windows can be open at once, each with its own
`PDFDocumentState`. `AppCommands` (the menu bar) reads the *focused* window's
state via `@FocusedValue(\.pdfDocumentState)`, published by
`PDFViewerContainer.focusedSceneValue(...)`. This avoids a shared mutable
app-wide "current document" singleton — the classic source of a menu command
firing against the wrong window when the user has more than one open.

## 8. The welcome window is the one deliberate AppKit-only piece

`DocumentGroup(viewing:)` has no "Untitled document" concept, so there is no
SwiftUI scene lifecycle hook for "show a welcome screen when nothing is open."
`AppDelegate` + `WelcomeWindowController` (plain `NSWindowController` hosting a
SwiftUI view via `NSHostingController`) fill that one gap. Everything else in
the app is SwiftUI, bridging to AppKit only where PDFKit itself requires it
(`PDFView`).

## 9. Position persistence: page + zoom only, keyed by path + size

`LastPositionStore` never stores document content, and never touches Recent
Documents (that's the system's own job). It stores a small `[String:
LastPosition]` dictionary in `UserDefaults`, keyed by the file's path, and
validates entries against the file's current size before trusting them — a
cheap, good-enough check that a moved/replaced/resized file won't silently
apply a stale page number. The entry count is capped, evicting the
least-recently-saved entries first.

## 10. Sandboxing and entitlements

App Sandbox is enabled. The only two entitlements requested are:

- `com.apple.security.files.user-selected.read-write` — covers reading any file
  the user opens (Open panel, drag-and-drop, Finder) *and* writing the
  destination the user picks for "Save a Copy" via `NSSavePanel`. The app never
  writes to the file it opened.
- `com.apple.security.print` — required for the native print dialog.

No app-scoped security bookmark entitlement is requested: macOS's Recent
Documents / Open Recent mechanism is itself backed by system-managed
security-scoped bookmarks external to the app, so it keeps working without the
app owning or persisting any bookmark data itself.

## 11. Build tooling: XcodeGen, not a hand-maintained `.pbxproj`

`project.yml` is the single source of truth for the Xcode project; the
`.xcodeproj` itself is generated (`xcodegen generate`) and gitignored. This
avoids the classic multi-contributor `.pbxproj` merge-conflict problem and
keeps the project configuration reviewable as plain, diffable YAML. XcodeGen is
a build-time developer tool, not a runtime dependency of the shipped app.

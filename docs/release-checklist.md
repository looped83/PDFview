# Release Checklist

Work through this top to bottom before tagging a release. Check off each item;
don't skip steps because a previous release passed them.

## 1. Code quality

- [ ] `git status` is clean — nothing uncommitted, nothing untracked that should be tracked.
- [ ] No `// TODO` / placeholder implementations left in shipped code paths.
- [ ] No force unwraps (`!`) that aren't demonstrably safe (documented if non-obvious).
- [ ] No suppressed warnings without a comment explaining why.
- [ ] `docs/architecture.md` still matches reality if you changed anything structural.
- [ ] `CHANGELOG.md` updated.

## 2. Automated tests

- [ ] Clean build succeeds: `scripts/build-release.sh` exits 0.
- [ ] All unit tests pass (`⌘U` in Xcode, or `xcodebuild test -scheme PDFViewer`).
- [ ] All UI tests pass on a clean simulator/local user session (they drive real windows —
      don't run them while doing other work on the same Mac).
- [ ] No new Swift 6 concurrency warnings.

## 3. Manual QA matrix

Test each of these at least once per release. Use PDFs you're allowed to
redistribute/keep locally — never commit test PDFs to the repository.

| Scenario | Checked |
|---|---|
| Small PDF (a few pages) | [ ] |
| Multi-hundred-page PDF | [ ] |
| Very large PDF (large file size / high-resolution images) | [ ] |
| PDF with mixed/unusual page sizes | [ ] |
| Scanned PDF with no text layer (search + selection correctly report "nothing found", nothing faked) | [ ] |
| PDF with a table of contents / outline | [ ] |
| PDF with no table of contents (empty state shown, not an error) | [ ] |
| PDF with internal links (jumping to the right page) | [ ] |
| PDF with external links (opens only after a user click) | [ ] |
| Password-protected PDF — correct password | [ ] |
| Password-protected PDF — incorrect password (clear error, can retry) | [ ] |
| Corrupted / non-PDF file with a `.pdf` extension (clear error, no crash) | [ ] |
| Multiple documents open simultaneously (menu commands act on the focused window only) | [ ] |
| Light appearance | [ ] |
| Dark appearance | [ ] |
| VoiceOver: open a document, navigate pages, use search, entirely by VoiceOver | [ ] |
| Keyboard-only: every core action reachable without a mouse/trackpad | [ ] |
| Reduce Motion enabled (no unexpected animation) | [ ] |
| Reduce Transparency enabled (sidebar/toolbar remain legible) | [ ] |

## 4. Performance (Instruments)

- [ ] Open a very large PDF — no beachball, no dropped frames during the initial render.
- [ ] Scroll quickly through a large document — smooth, no main-thread stalls (Time Profiler).
- [ ] Run a full-text search on a large document — UI stays responsive throughout (no
      main-thread blocking); cancel mid-search and confirm it actually stops.
- [ ] Leaks instrument shows no leaks after opening and closing several documents in a row.
- [ ] Memory returns to baseline after closing all open documents.
- [ ] No unexpected persistent background CPU usage while idle with a document open.

Record anything found — and the fix — in `CHANGELOG.md` under "Fixed", even for
an unreleased/internal build.

## 5. Build & package

- [ ] `scripts/build-release.sh` → `dist/PDF Viewer.app` produced.
- [ ] `scripts/create-dmg.sh` → `dist/PDFViewer.dmg` produced, contains the app and an
      `Applications` symlink, opens with a clean Finder layout.
- [ ] `scripts/verify-release.sh` reports no failures.

## 6. Signing & notarization (distribution builds only)

- [ ] `DEVELOPER_ID_APPLICATION` set to a valid, non-expired identity.
- [ ] `scripts/sign-app.sh` completes without error.
- [ ] `codesign --verify --deep --strict --verbose=2 dist/PDF Viewer.app` passes.
- [ ] `spctl --assess --type execute --verbose dist/PDF Viewer.app` passes.
- [ ] `scripts/notarize-app.sh` completes without error (Apple accepted the submission).
- [ ] `xcrun stapler validate dist/PDF Viewer.app` passes.
- [ ] DMG rebuilt *after* stapling, so it contains the stapled app: re-run
      `scripts/create-dmg.sh`.
- [ ] On a different Mac (or a fresh user account) with no prior Gatekeeper exception:
      download the DMG, mount it, launch the app, confirm no warning dialog beyond the
      normal "downloaded from the internet" prompt on first launch.

## 7. Final sanity pass

- [ ] Launch `dist/PDF Viewer.app` directly and confirm it opens, opens a PDF via drag-and-drop,
      and quits cleanly.
- [ ] Confirm no network requests are made (Little Snitch / Network Link Conditioner / a
      packet capture during normal use) — this app must work fully offline.
- [ ] Tag the release and update `CHANGELOG.md`'s version heading.

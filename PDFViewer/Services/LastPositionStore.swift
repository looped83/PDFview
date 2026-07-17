import Foundation

/// A single persisted viewing position for one file.
struct LastPosition: Codable, Equatable {
    var pageIndex: Int
    var zoomScale: Double
    var fileSize: Int
    var savedAt: Date
}

/// Persists only the last-viewed page and zoom scale per file — never document content.
/// Files are identified by path + size, which is good enough to survive normal use
/// (relaunch, reboot) while staying simple and privacy-friendly; if the file is moved,
/// replaced, or resized, the stale entry is silently ignored and evicted.
///
/// Backed by `UserDefaults` with a bounded, least-recently-used entry count so the store
/// cannot grow without limit over the lifetime of the app.
@MainActor
final class LastPositionStore {

    static let shared = LastPositionStore(defaults: .standard)

    private let defaults: UserDefaults
    private let storageKey = "com.brueggemann.pdfviewer.lastPositions"
    private let maximumEntries = 200

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func position(for url: URL) -> LastPosition? {
        guard let fileSize = fileSize(at: url) else { return nil }
        let entries = loadEntries()
        guard let entry = entries[key(for: url)], entry.fileSize == fileSize else { return nil }
        return entry
    }

    func savePosition(pageIndex: Int, zoomScale: Double, for url: URL) {
        guard let fileSize = fileSize(at: url) else { return }
        let position = LastPosition(pageIndex: pageIndex, zoomScale: zoomScale, fileSize: fileSize, savedAt: Date())
        var entries = loadEntries()
        entries[key(for: url)] = position
        if entries.count > maximumEntries {
            let oldestKeys = entries
                .sorted { $0.value.savedAt < $1.value.savedAt }
                .prefix(entries.count - maximumEntries)
                .map(\.key)
            for oldKey in oldestKeys {
                entries.removeValue(forKey: oldKey)
            }
        }
        store(entries)
    }

    private func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func fileSize(at url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }

    private func loadEntries() -> [String: LastPosition] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: LastPosition].self, from: data)) ?? [:]
    }

    private func store(_ entries: [String: LastPosition]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

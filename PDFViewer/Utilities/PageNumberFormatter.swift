import Foundation

enum PageNumberFormatter {

    /// "12 / 340", or "–" when there is no document loaded.
    static func pageStatus(current: Int, total: Int) -> String {
        guard total > 0 else { return "–" }
        return "\(current + 1) / \(total)"
    }

    /// Validates a 1-based page number string against the page count, returning the
    /// corresponding 0-based index, or `nil` if the input is not a valid page number.
    static func validatedPageIndex(from text: String, pageCount: Int) -> Int? {
        guard pageCount > 0, let value = Int(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        guard value >= 1, value <= pageCount else { return nil }
        return value - 1
    }
}

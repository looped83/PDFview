import Foundation

/// User-facing document error. Never wraps or displays raw system/Cocoa error text —
/// callers map into one of these cases so the UI can show a clear, actionable message.
enum PDFLoadError: LocalizedError, Equatable {
    case corrupted
    case unreadable
    case passwordRequired
    case incorrectPassword
    case unsupportedFileType

    var errorDescription: String? {
        switch self {
        case .corrupted:
            String(localized: "Die PDF-Datei ist beschädigt und kann nicht geöffnet werden.")
        case .unreadable:
            String(localized: "Die Datei konnte nicht gelesen werden.")
        case .passwordRequired:
            String(localized: "Diese PDF-Datei ist kennwortgeschützt.")
        case .incorrectPassword:
            String(localized: "Das eingegebene Kennwort ist nicht korrekt.")
        case .unsupportedFileType:
            String(localized: "Diese Datei ist kein gültiges PDF-Dokument.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .corrupted, .unreadable, .unsupportedFileType:
            String(localized: "Bitte wählen Sie eine andere Datei oder prüfen Sie, ob die Datei vollständig heruntergeladen wurde.")
        case .passwordRequired:
            String(localized: "Geben Sie das Kennwort ein, um das Dokument anzuzeigen.")
        case .incorrectPassword:
            String(localized: "Bitte versuchen Sie es erneut.")
        }
    }
}

import Testing
@testable import PDFViewer

struct PDFLoadErrorTests {

    @Test func everyCaseHasAUserFacingDescription() {
        let cases: [PDFLoadError] = [.corrupted, .unreadable, .passwordRequired, .incorrectPassword, .unsupportedFileType]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func recoverableErrorsProvideGuidance() {
        #expect(PDFLoadError.corrupted.recoverySuggestion?.isEmpty == false)
        #expect(PDFLoadError.passwordRequired.recoverySuggestion?.isEmpty == false)
        #expect(PDFLoadError.incorrectPassword.recoverySuggestion?.isEmpty == false)
    }
}

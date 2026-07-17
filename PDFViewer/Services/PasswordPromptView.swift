import SwiftUI

/// Shown in place of the PDF surface for a locked document. Never a modal sheet — a
/// full-window state is friendlier for something the user must resolve before there is
/// anything else to look at.
struct PasswordPromptView: View {
    let state: PDFDocumentState

    @State private var password: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.doc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Kennwort erforderlich")
                .font(.title3.bold())

            Text("Diese PDF-Datei ist kennwortgeschützt. Geben Sie das Kennwort ein, um sie anzuzeigen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            SecureField("Kennwort", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .focused($isFocused)
                .onSubmit(submit)
                .accessibilityLabel(Text("Kennwort"))

            if state.passwordAttemptFailed {
                Text("Das Kennwort ist nicht korrekt.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Entsperren", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        state.submitPassword(password)
    }
}

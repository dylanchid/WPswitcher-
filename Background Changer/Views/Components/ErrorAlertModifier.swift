import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onChange(of: error != nil) { hasError in
                isPresented = hasError
            }
            .alert(isPresented: $isPresented) {
                let content = error.map { ErrorPresenter.alertContent(for: $0) }
                return Alert(
                    title: Text(content?.title ?? "Error"),
                    message: Text([content?.message, content?.suggestion].compactMap { $0 }.joined(separator: "\n\n")),
                    dismissButton: .default(Text("OK")) { error = nil }
                )
            }
    }
}

extension View {
    func vmErrorAlert(_ error: Binding<Error?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

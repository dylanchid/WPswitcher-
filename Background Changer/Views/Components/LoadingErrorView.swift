import SwiftUI

struct LoadingErrorView: View {
    let isLoading: Bool
    let error: Error?
    let retryAction: (() -> Void)?
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error: error)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingErrorView(isLoading: true, error: nil, retryAction: nil)
            .frame(height: 200)
        
        LoadingErrorView(
            isLoading: false,
            error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"]),
            retryAction: {}
        )
        .frame(height: 200)
    }
    .padding()
} 
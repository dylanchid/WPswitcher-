import SwiftUI
import AppKit
import WallpaperTypes

struct HomeView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    @State private var isLoading: Bool = false
    @State private var error: Error?
    @State private var showError: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CurrentWallpaperSection(wallpaperManager: wallpaperManager, selectWallpaper: selectWallpaper)
                WallpaperGridSection(wallpaperManager: wallpaperManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
        .overlay(
            LoadingErrorView(
                isLoading: isLoading,
                error: error,
                retryAction: error != nil ? { selectWallpaper() } : nil
            )
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            let alert = error.map { ErrorPresenter.alertContent(for: $0) }
            Text([alert?.message, alert?.suggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
    }
    
    private func selectWallpaper() {
        isLoading = true
        error = nil
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    do {
                        try await wallpaperManager.addWallpapers([url])
                        await wallpaperManager.setWallpaper(from: url)
                    } catch {
                        self.error = error
                        showError = true
                    }
                    isLoading = false
                }
            }
        } else {
            isLoading = false
        }
    }
}

// MARK: - Current Wallpaper Section
struct CurrentWallpaperSection: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    let selectWallpaper: () -> Void
    
    var body: some View {
        if let (currentURL, currentScreen) = wallpaperManager.getCurrentSystemWallpaper() {
            HStack(alignment: .top, spacing: 20) {
                WallpaperPreviewView(url: currentURL)
                DisplaySettingsView(wallpaperManager: wallpaperManager)
            }
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)
        } else {
            NoWallpaperView(selectWallpaper: selectWallpaper)
        }
    }
}

struct WallpaperPreviewView: View {
    let url: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Wallpaper")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityLabel("Current wallpaper preview")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DisplaySettingsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Settings")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Picker("Display Mode", selection: $wallpaperManager.displayMode) {
                ForEach(WallpaperTypes.DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Display mode picker")
            
            Toggle("Show on All Spaces", isOn: Binding(
                get: { wallpaperManager.showOnAllSpaces },
                set: { wallpaperManager.updateShowOnAllSpaces($0) }
            ))
                .accessibilityLabel("Show wallpaper on all spaces toggle")
        }
        .frame(maxWidth: .infinity)
    }
}

struct NoWallpaperView: View {
    let selectWallpaper: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("No wallpaper selected")
                .font(.headline)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            Button(action: selectWallpaper) {
                Label("Choose Wallpaper", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Choose wallpaper button")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - Wallpaper Grid Section
struct WallpaperGridSection: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallpapers")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 60, maximum: 60), spacing: 8)
            ], spacing: 8) {
                ForEach(wallpaperManager.allWallpapers) { wallpaper in
                    WallpaperThumbnailView(wallpaper: wallpaper)
                        .accessibilityLabel("Wallpaper thumbnail: \(wallpaper.name)")
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(wallpaperManager: WallpaperManager.shared)
            .frame(width: 600, height: 400)
            .preferredColorScheme(.dark)
    }
} 
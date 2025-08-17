import SwiftUI
import AppKit
import Wallpaper
import WallpaperTypes

struct WallpaperThumbnailView: View {
    let wallpaper: WallpaperItem
    @StateObject var wallpaperManager: WallpaperManager = WallpaperManager.shared
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var lastError: Error?
    @State private var thumbnailImage: NSImage?
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                thumbnailView(image: image)
            } else {
                placeholderView
            }
        }
        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            let alert = lastError.map { ErrorPresenter.alertContent(for: $0) }
            Text([alert?.message, alert?.suggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 60, height: 60)
            .cornerRadius(6)
    }
    
    private func thumbnailView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .cornerRadius(6)
            .onTapGesture {
                let url = wallpaper.url
                Task {
                    await wallpaperManager.setWallpaper(from: url)
                }
            }
            .contextMenu {
                Button(action: {
                    let url = wallpaper.url
                    Task {
                        await wallpaperManager.setWallpaper(from: url)
                    }
                }) {
                    Label("Set as Wallpaper", systemImage: "photo")
                }
            }
    }
    
    private func loadThumbnail() async {
        guard thumbnailImage == nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let image = NSImage(contentsOf: wallpaper.url) {
                thumbnailImage = image
            }
        } catch {
            lastError = error
            showError = true
        }
    }
}

// MARK: - Preview Provider
struct WallpaperThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockWallpaper = WallpaperItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/path/to/image.jpg"),
            name: "Test Image"
        )
        WallpaperThumbnailView(wallpaper: mockWallpaper)
            .frame(width: 100, height: 100)
            .preferredColorScheme(.dark)
    }
} 
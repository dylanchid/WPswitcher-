import SwiftUI
import AppKit
import Wallpaper

struct WallpaperThumbnailView: View {
    let wallpaper: WallpaperItem
    @StateObject var wallpaperManager: WallpaperManager = WallpaperManager.shared
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
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
            Text(wallpaper.lastError?.errorDescription ?? "Unknown error")
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
                if let url = wallpaper.fileURL {
                    try? wallpaperManager.setWallpaper(from: url)
                }
            }
            .contextMenu {
                Button(action: {
                    if let url = wallpaper.fileURL {
                        try? wallpaperManager.setWallpaper(from: url)
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
            let image = try await wallpaper.loadImage()
            thumbnailImage = image
        } catch {
            showError = true
        }
    }
}

// MARK: - Preview Provider
struct WallpaperThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockWallpaper = WallpaperItem(
            id: UUID(),
            path: "/path/to/image.jpg",
            name: "Test Image",
            isSelected: false
        )
        WallpaperThumbnailView(wallpaper: mockWallpaper)
            .frame(width: 100, height: 100)
            .preferredColorScheme(.dark)
    }
} 
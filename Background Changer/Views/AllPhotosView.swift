import SwiftUI
import AppKit
import Wallpaper

struct AllPhotosView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(wallpaperManager.allWallpapers) { wallpaper in
                    WallpaperThumbnailView(wallpaper: wallpaper)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview Provider
struct AllPhotosView_Previews: PreviewProvider {
    static var previews: some View {
        AllPhotosView(wallpaperManager: WallpaperManager.shared)
            .frame(width: 600, height: 400)
            .preferredColorScheme(.dark)
    }
} 
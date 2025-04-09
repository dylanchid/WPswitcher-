import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var selectedTab: Int? = 1
    @State private var showingCreatePlaylist = false
    @State private var showingEditPlaylist = false
    @State private var selectedPlaylist: Playlist?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Background Changer")
                    .font(.headline)
                    .themedText()
                Spacer()
                Button(action: {
                    NSApp.sendAction(#selector(NSApp.terminate(_:)), to: nil, from: nil)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(themeManager.theme.secondaryTextColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(themeManager.theme.backgroundColor)
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            // Quick Actions
            VStack(spacing: 8) {
                QuickActionButton(
                    title: "Next Wallpaper",
                    icon: "arrow.right",
                    action: { wallpaperManager.nextWallpaper() }
                )
                
                QuickActionButton(
                    title: "Previous Wallpaper",
                    icon: "arrow.left",
                    action: { wallpaperManager.previousWallpaper() }
                )
                
                QuickActionButton(
                    title: "Random Wallpaper",
                    icon: "shuffle",
                    action: { wallpaperManager.randomWallpaper() }
                )
            }
            .padding()
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            // Playlists
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(wallpaperManager.userProfile.playlists) { playlist in
                        PlaylistMenuItem(playlist: playlist)
                    }
                }
                .padding()
            }
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            // Settings
            HStack {
                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Label("Settings", systemImage: "gear")
                        .themedText()
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }) {
                    Label("Open Main Window", systemImage: "window")
                        .themedText()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .frame(width: 300)
        .themedBackground()
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView(wallpaperManager: wallpaperManager)
        }
        .sheet(isPresented: $showingEditPlaylist) {
            if let playlist = selectedPlaylist {
                EditPlaylistView(wallpaperManager: wallpaperManager, playlist: playlist)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(8)
            .background(isHovered ? themeManager.theme.highlightColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .themedText()
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PlaylistMenuItem: View {
    @ObservedObject var playlist: Playlist
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(playlist.name)
                    .themedText()
                Text("\(playlist.wallpapers.count) wallpapers")
                    .themedSecondaryText()
                    .font(.caption)
            }
            
            Spacer()
            
            Button(action: {
                playlist.isEnabled.toggle()
            }) {
                Image(systemName: playlist.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(themeManager.theme.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(isHovered ? themeManager.theme.highlightColor : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview Provider
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(AppState())
            .preferredColorScheme(.dark)
    }
} 
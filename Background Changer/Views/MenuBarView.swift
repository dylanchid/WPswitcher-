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
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            MenuBarHeaderView()
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            QuickActionsView(wallpaperManager: wallpaperManager)
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            PlaylistListView(
                playlists: wallpaperManager.userProfile.playlists,
                selectedPlaylist: $selectedPlaylist,
                showingEditPlaylist: $showingEditPlaylist
            )
            
            Divider()
                .background(themeManager.theme.borderColor)
            
            MenuBarFooterView()
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
    }
}

// MARK: - Menu Bar Header
struct MenuBarHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
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
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 8) {
            QuickActionButton(
                title: "Next Wallpaper",
                icon: "arrow.right",
                action: { performAction(wallpaperManager.nextWallpaper) }
            )
            
            QuickActionButton(
                title: "Previous Wallpaper",
                icon: "arrow.left",
                action: { performAction(wallpaperManager.previousWallpaper) }
            )
            
            QuickActionButton(
                title: "Random Wallpaper",
                icon: "shuffle",
                action: { performAction(wallpaperManager.randomWallpaper) }
            )
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func performAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            self.error = error
            showError = true
        }
    }
}

// MARK: - Playlist List
struct PlaylistListView: View {
    let playlists: [Playlist]
    @Binding var selectedPlaylist: Playlist?
    @Binding var showingEditPlaylist: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(playlists) { playlist in
                    PlaylistMenuItem(
                        playlist: playlist,
                        onEdit: {
                            selectedPlaylist = playlist
                            showingEditPlaylist = true
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Menu Bar Footer
struct MenuBarFooterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
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
}

// MARK: - Quick Action Button
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

// MARK: - Playlist Menu Item
struct PlaylistMenuItem: View {
    @ObservedObject var playlist: PlaylistEntity
    let onEdit: () -> Void
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
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(themeManager.theme.secondaryTextColor)
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
            .environmentObject(WallpaperManager.shared)
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
    }
} 
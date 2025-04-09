import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(1)
            
            PlaylistSettingsView()
                .tabItem {
                    Label("Playlists", systemImage: "list.bullet")
                }
                .tag(2)
            
            AccessibilitySettingsView()
                .tabItem {
                    Label("Accessibility", systemImage: "accessibility")
                }
                .tag(3)
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        Form {
            Section(header: Text("General Settings")) {
                Toggle("Start at Login", isOn: $wallpaperManager.userProfile.preferences.startAtLogin)
                Toggle("Show in Dock", isOn: $wallpaperManager.userProfile.preferences.showInDock)
                Toggle("Show in Menu Bar", isOn: $wallpaperManager.userProfile.preferences.showInMenuBar)
            }
            
            Section(header: Text("Wallpaper Settings")) {
                Picker("Display Mode", selection: $wallpaperManager.userProfile.preferences.displayMode) {
                    Text("Fill").tag(DisplayMode.fill)
                    Text("Fit").tag(DisplayMode.fit)
                    Text("Stretch").tag(DisplayMode.stretch)
                    Text("Center").tag(DisplayMode.center)
                    Text("Tile").tag(DisplayMode.tile)
                }
                
                Toggle("Random Order", isOn: $wallpaperManager.userProfile.preferences.randomOrder)
                Toggle("Change on Wake", isOn: $wallpaperManager.userProfile.preferences.changeOnWake)
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Form {
            Section(header: Text("Color Scheme")) {
                Picker("Appearance", selection: $themeManager.theme.colorScheme) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                    Text("System").tag(ColorScheme.system)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Colors")) {
                ColorPicker("Accent Color", selection: $themeManager.theme.accentColor)
                ColorPicker("Background Color", selection: $themeManager.theme.backgroundColor)
                ColorPicker("Text Color", selection: $themeManager.theme.textColor)
                ColorPicker("Secondary Text Color", selection: $themeManager.theme.secondaryTextColor)
            }
            
            Section(header: Text("Customization")) {
                Toggle("Use Custom Colors", isOn: Binding(
                    get: { themeManager.theme.colorScheme != .system },
                    set: { newValue in
                        if !newValue {
                            themeManager.theme = Theme.current
                        }
                    }
                ))
            }
        }
        .padding()
    }
}

struct PlaylistSettingsView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        Form {
            Section(header: Text("Playlist Management")) {
                List {
                    ForEach(wallpaperManager.userProfile.playlists) { playlist in
                        PlaylistRow(playlist: playlist)
                    }
                    .onMove { indices, newOffset in
                        wallpaperManager.userProfile.playlists.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                
                Button(action: {
                    wallpaperManager.createNewPlaylist()
                }) {
                    Label("New Playlist", systemImage: "plus")
                }
            }
            
            Section(header: Text("Playlist Settings")) {
                Toggle("Show Playlist Names", isOn: $wallpaperManager.userProfile.preferences.showPlaylistNames)
                Toggle("Show Wallpaper Count", isOn: $wallpaperManager.userProfile.preferences.showWallpaperCount)
            }
        }
        .padding()
    }
}

struct PlaylistRow: View {
    @ObservedObject var playlist: Playlist
    @EnvironmentObject var themeManager: ThemeManager
    
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
        .padding(.vertical, 4)
    }
}

struct AccessibilitySettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Form {
            Section(header: Text("Visual Accessibility")) {
                Toggle("Increase Contrast", isOn: Binding(
                    get: { themeManager.theme.textColor == .black || themeManager.theme.textColor == .white },
                    set: { newValue in
                        if newValue {
                            themeManager.theme.textColor = themeManager.theme.colorScheme == .dark ? .white : .black
                        }
                    }
                ))
                
                Toggle("Reduce Motion", isOn: .constant(false))
                Toggle("Reduce Transparency", isOn: .constant(false))
            }
            
            Section(header: Text("Keyboard Navigation")) {
                Toggle("Full Keyboard Access", isOn: .constant(true))
                Toggle("Keyboard Shortcuts", isOn: .constant(true))
            }
            
            Section(header: Text("Screen Reader")) {
                Toggle("VoiceOver Support", isOn: .constant(true))
                Toggle("Dynamic Type", isOn: .constant(true))
            }
        }
        .padding()
    }
}

// MARK: - Preview Provider
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 600, height: 400)
            .preferredColorScheme(.dark)
    }
} 
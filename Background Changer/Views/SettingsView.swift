import SwiftUI
import WallpaperTypes

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
                    Text("Fill").tag(DisplayMode.fillScreen)
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
                ColorPicker("Accent Color", selection: Binding(
                    get: { themeManager.theme.accentColor.color },
                    set: { themeManager.theme.accentColor = CodableColor($0) }
                ))
                ColorPicker("Background Color", selection: Binding(
                    get: { themeManager.theme.backgroundColor.color },
                    set: { themeManager.theme.backgroundColor = CodableColor($0) }
                ))
                ColorPicker("Text Color", selection: Binding(
                    get: { themeManager.theme.textColor.color },
                    set: { themeManager.theme.textColor = CodableColor($0) }
                ))
                ColorPicker("Secondary Text Color", selection: Binding(
                    get: { themeManager.theme.secondaryTextColor.color },
                    set: { themeManager.theme.secondaryTextColor = CodableColor($0) }
                ))
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
    @EnvironmentObject var playlistService: PlaylistService
    
    var body: some View {
        Form {
            Section(header: Text("Playlist Management")) {
                List {
                    ForEach(playlistService.playlists) { playlist in
                        PlaylistRow(playlist: playlist)
                    }
                    .onMove { indices, newOffset in
                        // playlistService.movePlaylist(from: indices, to: newOffset)
                    }
                }
                
                Button(action: {
                    // playlistService.createPlaylist(name: "New Playlist")
                }) {
                    Label("New Playlist", systemImage: "plus")
                }
            }
            
            Section(header: Text("Playlist Settings")) {
                Toggle("Show Playlist Names", isOn: .constant(true))
                Toggle("Show Wallpaper Count", isOn: .constant(true))
            }
        }
        .padding()
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
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
                // playlist.isEnabled.toggle()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeManager.theme.accentColor.color)
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
                    get: { themeManager.theme.textColor.color == .black || themeManager.theme.textColor.color == .white },
                    set: { newValue in
                        if newValue {
                            themeManager.theme.textColor = CodableColor(themeManager.theme.colorScheme == .dark ? .white : .black)
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
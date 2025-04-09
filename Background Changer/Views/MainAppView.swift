//
//  ContentView.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            SidebarView()
                .frame(minWidth: 200)
            
            TabView(selection: $selectedTab) {
                WallpaperGridView()
                    .tabItem {
                        Label("Wallpapers", systemImage: "photo")
                    }
                    .tag(0)
                
                PlaylistView()
                    .tabItem {
                        Label("Playlists", systemImage: "list.bullet")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
        }
        .themedBackground()
        .environment(\.colorScheme, themeManager.theme.colorScheme == .dark ? .dark : .light)
    }
}

struct SidebarView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        List {
            Section(header: Text("Library").themedText()) {
                NavigationLink(destination: WallpaperGridView()) {
                    Label("All Wallpapers", systemImage: "photo")
                        .themedText()
                }
                
                NavigationLink(destination: PlaylistView()) {
                    Label("Playlists", systemImage: "list.bullet")
                        .themedText()
                }
            }
            
            Section(header: Text("Playlists").themedText()) {
                ForEach(wallpaperManager.userProfile.playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        HStack {
                            Text(playlist.name)
                                .themedText()
                            Spacer()
                            Text("\(playlist.wallpapers.count)")
                                .themedSecondaryText()
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .themedBackground()
    }
}

struct WallpaperGridView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    
    var filteredWallpapers: [WallpaperItem] {
        if searchText.isEmpty {
            return wallpaperManager.wallpapers
        } else {
            return wallpaperManager.wallpapers.filter { wallpaper in
                wallpaper.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText)
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredWallpapers) { wallpaper in
                        WallpaperThumbnailView(wallpaper: wallpaper)
                            .themedBorder()
                    }
                }
                .padding()
            }
        }
        .themedBackground()
    }
}

struct SearchBar: View {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.theme.secondaryTextColor)
            
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .themedText()
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.theme.secondaryTextColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(themeManager.theme.backgroundColor)
        .cornerRadius(8)
        .themedBorder()
    }
}

struct WallpaperThumbnailView: View {
    let wallpaper: WallpaperItem
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(fileURLWithPath: wallpaper.filePath)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(height: 150)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                case .failure:
                    Image(systemName: "photo")
                        .frame(height: 150)
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.name)
                    .themedText()
                    .lineLimit(1)
                
                Text(wallpaper.filePath)
                    .themedSecondaryText()
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .background(themeManager.theme.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.theme.borderColor, lineWidth: isHovered ? 2 : 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

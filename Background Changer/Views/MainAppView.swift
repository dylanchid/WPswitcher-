//
//  ContentView.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//

import SwiftUI
import WallpaperTypes

struct MainAppView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var rotationVM: RotationViewModel
    @State private var selectedTab = 0
    @AppStorage("lastSelectedTab") private var lastSelectedTab = 0
    
    var body: some View {
        NavigationView {
            SidebarView(selectedTab: $selectedTab)
                .frame(minWidth: 200)
            
            TabView(selection: $selectedTab) {
                WallpaperGridView()
                    .tabItem {
                        Label("Wallpapers", systemImage: "photo")
                    }
                    .tag(0)
                
                PlaylistsView()
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
    .vmErrorAlert($rotationVM.lastError)
    .onChange(of: selectedTab) { lastSelectedTab = $0 }
        .onAppear {
            selectedTab = lastSelectedTab
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTab: Int
    
    var body: some View {
        List(selection: $selectedTab) {
            Section(header: Text("Library").themedText()) {
                NavigationLink(destination: WallpaperGridView()) {
                    Label("All Wallpapers", systemImage: "photo")
                        .themedText()
                }
                .tag(0)
                
                NavigationLink(destination: PlaylistsView()) {
                    Label("Playlists", systemImage: "list.bullet")
                        .themedText()
                }
                .tag(1)
            }
            
            Section(header: Text("Playlists").themedText()) {
                NavigationLink(destination: PlaylistsView()) {
                    Label("Manage Playlists", systemImage: "list.bullet")
                        .themedText()
                }
                .tag(1)
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
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
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
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        }
        .themedBackground()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            let alert = error.map { ErrorPresenter.alertContent(for: $0) }
            Text([alert?.message, alert?.suggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
        .task {
            await loadWallpapers()
        }
    }
    
    private func loadWallpapers() async {
        isLoading = true
        do {
            try await wallpaperManager.loadWallpapers()
        } catch {
            self.error = error
            showError = true
        }
        isLoading = false
    }
}

struct SearchBar: View {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.theme.secondaryTextColorValue)
            
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .themedText()
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.theme.secondaryTextColorValue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
    .background(themeManager.theme.backgroundColorValue)
        .cornerRadius(8)
        .themedBorder()
    }
}

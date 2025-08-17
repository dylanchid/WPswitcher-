//
//  RotationViewModel.swift
//  Background Changer
//
//  MVVM-C: Extract logic from managers into a UI-agnostic ViewModel facade.
//

import Foundation
import Combine
import SwiftUI
import WallpaperTypes
import Wallpaper

@MainActor
final class RotationViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published private(set) var isRotating: Bool = false
    @Published private(set) var rotationInterval: TimeInterval = 3600
    @Published private(set) var playlists: [Wallpaper.Playlist] = []
    @Published private(set) var activePlaylistId: UUID?
    @Published var lastError: Error?
    @Published private(set) var userSettings: UserSettings

    // MARK: - Dependencies
    private let wallpaperService: AppWallpaperServiceProtocol
    private let playlistService: Wallpaper.PlaylistServiceProtocol
    private let userSettingsService: UserSettingsServiceProtocol

    init(wallpaperService: AppWallpaperServiceProtocol,
         playlistService: Wallpaper.PlaylistServiceProtocol,
         userSettingsService: UserSettingsServiceProtocol) {
        self.wallpaperService = wallpaperService
        self.playlistService = playlistService
        self.userSettingsService = userSettingsService
        self.userSettings = userSettingsService.userSettings
        loadInitial()
    }

    // MARK: - Lifecycle
    private func loadInitial() {
        Task {
            do {
                self.playlists = try await playlistService.getPlaylists()
                self.activePlaylistId = playlistService.currentPlaylist?.id
            } catch {
                self.lastError = error
            }
        }
    }

    // MARK: - Playlist Management
    func createPlaylist(name: String) async throws {
        _ = try await playlistService.createPlaylist(name: name)
        self.playlists = try await playlistService.getPlaylists()
    }

    func deletePlaylist(id: UUID) async throws {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        try await playlistService.deletePlaylist(playlist)
        self.playlists = try await playlistService.getPlaylists()
    }

    func renamePlaylist(id: UUID, to newName: String) async throws {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        try await playlistService.renamePlaylist(playlist, to: newName)
        self.playlists = try await playlistService.getPlaylists()
    }

    // MARK: - Wallpaper Management
    func addWallpapers(to playlistId: UUID, urls: [URL]) async throws {
        guard let playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        for url in urls {
            let wallpaper = WallpaperItem(id: UUID(), url: url, name: url.lastPathComponent)
            try await playlistService.addWallpaper(wallpaper, to: playlist)
        }
        self.playlists = try await playlistService.getPlaylists()
    }

    func removeWallpapers(from playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        let wallpapersToRemove = playlist.wallpapers.filter { wallpaperIds.contains($0.id) }
        for wallpaper in wallpapersToRemove {
            try await playlistService.removeWallpaper(wallpaper, from: playlist)
        }
        self.playlists = try await playlistService.getPlaylists()
    }

    // MARK: - Rotation Control
    func startRotation(playlistId: UUID) {
        if let playlist = playlists.first(where: { $0.id == playlistId }) {
            var mutablePlaylistService = self.playlistService
            mutablePlaylistService.currentPlaylist = playlist
            self.activePlaylistId = playlist.id
            self.isRotating = true
        }
    }

    func stopRotation() {
        isRotating = false
        var mutablePlaylistService = self.playlistService
        mutablePlaylistService.currentPlaylist = nil
        self.activePlaylistId = nil
    }

    // MARK: - Settings
    func updateRotationInterval(for playlistId: UUID, interval: TimeInterval) async throws {
        guard var playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        playlist.rotationInterval = interval
        // The protocol doesn't specify an update method. Assuming the service persists on set.
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[index] = playlist
        }
    }

    func updatePlaybackMode(for playlistId: UUID, mode: Wallpaper.PlaybackMode) async throws {
        guard var playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        playlist.playbackMode = mode
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[index] = playlist
        }
    }
}

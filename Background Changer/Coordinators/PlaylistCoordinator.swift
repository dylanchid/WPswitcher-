//
//  PlaylistCoordinator.swift
//  Background Changer
//
//  Owns playlist-related flows (create/edit/manage) under MVVM-C.
//

import AppKit
import SwiftUI
import Wallpaper

@MainActor
final class PlaylistCoordinator: BaseCoordinator {
    private let appCoordinator: AppCoordinator
    private let viewModel: RotationViewModel
    private let router: PlaylistFlowRouter

    init(appCoordinator: AppCoordinator, viewModel: RotationViewModel, router: PlaylistFlowRouter) {
        self.appCoordinator = appCoordinator
        self.viewModel = viewModel
        self.router = router
        super.init()
    }

    override func start() {
        // No-op for now; hook if we push dedicated playlist windows/screens.
    }

    func startCreateFlow() {
    // TODO: Present create playlist flow via coordinator-managed UI (window/screen)
    }

    func startEditFlow(playlist: Wallpaper.Playlist) {
    // TODO: Present edit playlist flow via coordinator-managed UI (window/screen)
    }

    // Centralized delete confirmation and action
    func confirmDelete(playlist: Wallpaper.Playlist) {
        let alert = NSAlert()
        alert.messageText = "Delete Playlist"
        alert.informativeText = "Are you sure you want to delete this playlist? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        Task { @MainActor in
            do {
                try await viewModel.deletePlaylist(id: playlist.id)
            } catch {
                print("Error deleting playlist: \(error.localizedDescription)")
            }
        }
    }
    
    func showWallpaperPicker(for playlist: Playlist) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [.image]

        if openPanel.runModal() == .OK {
            Task {
                do {
                    try await viewModel.addWallpapers(to: playlist.id, urls: openPanel.urls)
                } catch {
                    print("Error adding wallpapers: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func showEditPlaylistView(playlist: Playlist) {
        // This would typically trigger a flow to present the edit view
        // For now, we'll delegate to the router's flow mechanism
        router.activeFlow = .rename(playlist)
    }

    func showCreatePlaylistView() {
        // This would typically trigger a flow to present the create view
        // For now, we'll delegate to the router's flow mechanism
        router.activeFlow = .create
    }
}

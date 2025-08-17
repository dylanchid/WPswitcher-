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
            await viewModel.deletePlaylist(id: playlist.id)
        }
    }
}

//
//  ContentView.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedImagePath: String = ""
    @State private var rotationInterval: Double = 60 // Default: Change wallpaper every 60 seconds
    @State private var isRotating: Bool = false
    private let wallpaperManager = WallpaperManager.shared

    var body: some View {
        VStack {
            Text("Wallpaper Changer")
                .font(.largeTitle)
                .padding()

            // Select Image Button
            Button("Select Image") {
                selectImage()
            }
            .padding()
            
            if !selectedImagePath.isEmpty {
                Text("Selected: \(selectedImagePath)")
                    .font(.caption)
                    .padding()

                // Set Wallpaper Button
                Button("Set Wallpaper") {
                    if let url = URL(string: selectedImagePath) {
                        try? wallpaperManager.setWallpaper(from: url)
                        wallpaperManager.addWallpapers([url])
                    }
                }
                .padding()
            }
            
            Divider().padding(.vertical)

            // Rotation Interval Slider
            VStack {
                Text("Rotation Interval: \(Int(rotationInterval)) sec")
                    .font(.headline)
                Slider(value: $rotationInterval, in: 10...600, step: 10) // 10s to 10 min
                    .padding()
            }

            // Start/Stop Rotation Buttons
            HStack {
                Button(isRotating ? "Stop Rotation" : "Start Rotation") {
                    if isRotating {
                        wallpaperManager.stopRotation()
                    } else {
                        wallpaperManager.startRotation(interval: rotationInterval)
                    }
                    isRotating.toggle()
                }
                .padding()
                .background(isRotating ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Clear Rotation List") {
                    wallpaperManager.clearWallpapers()
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(width: 450, height: 300)
        .padding()
    }

    /// Opens file picker to select an image
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            selectedImagePath = panel.url?.path ?? ""
        }
    }
}

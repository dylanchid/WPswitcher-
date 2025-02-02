import SwiftUI

struct MenuBarView: View {
    @State private var selectedImagePath: String = ""
    @State private var rotationInterval: Double = 60 // Default: 60s
    @State private var isRotating: Bool = false
    private let wallpaperManager = WallpaperManager.shared

    var body: some View {
        VStack {
            Text("Wallpaper Changer")
                .font(.headline)
                .padding()

            Button("Select Image") {
                selectImage()
            }
            .padding()

            if !selectedImagePath.isEmpty {
                Text("Selected: \(selectedImagePath)")
                    .font(.caption)
                    .padding()

                Button("Set Wallpaper") {
                    wallpaperManager.setWallpaper(from: selectedImagePath)
                    wallpaperManager.addWallpaper(path: selectedImagePath)
                }
                .padding()
            }

            Divider()

            // Rotation Interval Slider
            VStack {
                Text("Rotation Interval: \(Int(rotationInterval)) sec")
                    .font(.caption)
                Slider(value: $rotationInterval, in: 10...600, step: 10)
                    .padding()
            }

            // Start/Stop Rotation Button
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
        }
        .frame(width: 280, height: 240)
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
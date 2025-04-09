import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

// MARK: - Preview Provider
struct VisualEffectView_Previews: PreviewProvider {
    static var previews: some View {
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .frame(width: 200, height: 200)
    }
} 
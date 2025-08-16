import SwiftUI

enum ColorScheme: String, Codable {
    case light
    case dark
    case system
}

// Codable wrapper for Color
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    init(_ color: Color) {
        // Default values, in a real implementation you'd extract components
        self.red = 0.0
        self.green = 0.0
        self.blue = 0.0
        self.alpha = 1.0
    }
}

struct Theme: Codable {
    var colorScheme: ColorScheme
    var accentColor: CodableColor
    var backgroundColor: CodableColor
    var textColor: CodableColor
    var secondaryTextColor: CodableColor
    var borderColor: CodableColor
    var highlightColor: CodableColor
    
    // Computed properties that return actual Color objects
    var accentColorValue: Color { accentColor.color }
    var backgroundColorValue: Color { backgroundColor.color }
    var textColorValue: Color { textColor.color }
    var secondaryTextColorValue: Color { secondaryTextColor.color }
    var borderColorValue: Color { borderColor.color }
    var highlightColorValue: Color { highlightColor.color }
    
    static let light = Theme(
        colorScheme: .light,
        accentColor: CodableColor(.blue),
        backgroundColor: CodableColor(.white),
        textColor: CodableColor(.black),
        secondaryTextColor: CodableColor(.gray),
        borderColor: CodableColor(.gray.opacity(0.3)),
        highlightColor: CodableColor(.blue.opacity(0.1))
    )
    
    static let dark = Theme(
        colorScheme: .dark,
        accentColor: CodableColor(.blue),
        backgroundColor: CodableColor(Color(NSColor.windowBackgroundColor)),
        textColor: CodableColor(.white),
        secondaryTextColor: CodableColor(.gray),
        borderColor: CodableColor(.gray.opacity(0.3)),
        highlightColor: CodableColor(.blue.opacity(0.2))
    )
    
    static var current: Theme {
        switch UserDefaults.standard.string(forKey: "colorScheme") {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var theme: Theme {
        didSet {
            saveTheme()
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "theme"),
           let savedTheme = try? JSONDecoder().decode(Theme.self, from: data) {
            self.theme = savedTheme
        } else {
            self.theme = Theme.current
        }
    }
    
    private func saveTheme() {
        if let data = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(data, forKey: "theme")
        }
    }
    
    func updateColorScheme(_ scheme: ColorScheme) {
        theme.colorScheme = scheme
        UserDefaults.standard.set(scheme.rawValue, forKey: "colorScheme")
    }
}

// Theme-specific view modifiers
struct ThemedBackground: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.theme.backgroundColorValue)
    }
}

struct ThemedText: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.theme.textColorValue)
    }
}

struct ThemedSecondaryText: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.theme.secondaryTextColorValue)
    }
}

struct ThemedBorder: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.theme.borderColorValue, lineWidth: 1)
            )
    }
}

// View extensions for easy access
extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
    
    func themedText() -> some View {
        modifier(ThemedText())
    }
    
    func themedSecondaryText() -> some View {
        modifier(ThemedSecondaryText())
    }
    
    func themedBorder() -> some View {
        modifier(ThemedBorder())
    }
} 
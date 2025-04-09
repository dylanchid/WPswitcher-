import SwiftUI

enum ColorScheme: String, Codable {
    case light
    case dark
    case system
}

struct Theme: Codable {
    var colorScheme: ColorScheme
    var accentColor: Color
    var backgroundColor: Color
    var textColor: Color
    var secondaryTextColor: Color
    var borderColor: Color
    var highlightColor: Color
    
    static let light = Theme(
        colorScheme: .light,
        accentColor: .blue,
        backgroundColor: .white,
        textColor: .black,
        secondaryTextColor: .gray,
        borderColor: .gray.opacity(0.3),
        highlightColor: .blue.opacity(0.1)
    )
    
    static let dark = Theme(
        colorScheme: .dark,
        accentColor: .blue,
        backgroundColor: Color(NSColor.windowBackgroundColor),
        textColor: .white,
        secondaryTextColor: .gray,
        borderColor: .gray.opacity(0.3),
        highlightColor: .blue.opacity(0.2)
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
            .background(themeManager.theme.backgroundColor)
    }
}

struct ThemedText: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.theme.textColor)
    }
}

struct ThemedSecondaryText: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.theme.secondaryTextColor)
    }
}

struct ThemedBorder: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.theme.borderColor, lineWidth: 1)
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
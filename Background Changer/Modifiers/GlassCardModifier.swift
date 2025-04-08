//
//  GlassCardModifier.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 4/7/25.
//

import SwiftUI

struct GlassCardModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: .black.opacity(0.15), radius: isHovered ? 20 : 10)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
}

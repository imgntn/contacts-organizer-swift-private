//
//  TextScaleEnvironment.swift
//  Contacts Organizer
//
//  Custom environment value for text scaling across the app
//

import SwiftUI

// MARK: - Text Scale

enum TextScale: String, CaseIterable {
    case normal = "normal"
    case large = "large"
    case xlarge = "xlarge"

    var multiplier: CGFloat {
        switch self {
        case .normal: return 1.0
        case .large: return 1.15
        case .xlarge: return 1.3
        }
    }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .large: return "Large"
        case .xlarge: return "Extra Large"
        }
    }
}

// MARK: - Environment Key

private struct TextScaleKey: EnvironmentKey {
    static let defaultValue: TextScale = .large
}

extension EnvironmentValues {
    var textScale: TextScale {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

// MARK: - Responsive Font Modifier

extension View {
    func responsiveFont(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ResponsiveFontModifier(baseSize: baseSize, weight: weight))
    }
}

struct ResponsiveFontModifier: ViewModifier {
    @Environment(\.textScale) private var textScale
    let baseSize: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: baseSize * textScale.multiplier, weight: weight))
    }
}

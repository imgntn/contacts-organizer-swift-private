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
    static let defaultValue: TextScale = .normal
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

    /// Default body size that adapts to the current platform (13 pt on macOS per HIG).
    func platformBodyFont(weight: Font.Weight = .regular) -> some View {
        responsiveFont(PlatformTypography.body, weight: weight)
    }

    /// Callout/subheadline size that follows Apple guidance per platform.
    func platformCalloutFont(weight: Font.Weight = .regular) -> some View {
        responsiveFont(PlatformTypography.callout, weight: weight)
    }

    /// Caption size for secondary metadata.
    func platformCaptionFont(weight: Font.Weight = .regular) -> some View {
        responsiveFont(PlatformTypography.caption, weight: weight)
    }

    /// Extra-small caption used for badges or tight Glyph + text combos.
    func platformMiniCaptionFont(weight: Font.Weight = .regular) -> some View {
        responsiveFont(PlatformTypography.miniCaption, weight: weight)
    }
}

struct PlatformTypography {
    static var body: CGFloat {
#if os(macOS)
        return 13
#elseif os(iOS)
        return 17
#else
        return 13
#endif
    }

    static var callout: CGFloat {
#if os(macOS)
        return 12
#elseif os(iOS)
        return 16
#else
        return 12
#endif
    }

    static var caption: CGFloat {
#if os(macOS)
        return 11
#elseif os(iOS)
        return 12
#else
        return 11
#endif
    }

    static var miniCaption: CGFloat {
#if os(macOS)
        return 10
#elseif os(iOS)
        return 11
#else
        return 10
#endif
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

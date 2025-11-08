import SwiftUI

// MARK: - Window Size Environment

private struct WindowSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    var windowSize: CGSize {
        get { self[WindowSizeKey.self] }
        set { self[WindowSizeKey.self] = newValue }
    }
}

private struct WindowSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct WindowSizeTracker: ViewModifier {
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: WindowSizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(WindowSizePreferenceKey.self) { newSize in
                self.size = newSize
            }
            .environment(\.windowSize, size)
    }
}

extension View {
    /// Tracks the current view's window size and injects it into the environment
    func trackWindowSize() -> some View {
        modifier(WindowSizeTracker())
    }
}

// MARK: - Paragraph Text Modifier

struct ParagraphTextStyle: ViewModifier {
    @Environment(\.windowSize) private var windowSize
    /// Base paragraph size (larger than the default macOS body size ~13)
    var baseSize: CGFloat = 15

    func body(content: Content) -> some View {
        let width = windowSize.width
        // Map width from 800->1600 to a scale of 1.0->1.3, clamp outside that range
        let t: CGFloat
        if width <= 0 {
            t = 0
        } else {
            let normalized = (width - 800) / 800
            t = min(max(normalized, 0), 1)
        }
        let scale: CGFloat = 1.0 + 0.3 * t
        let size = baseSize * scale

        return content.font(.system(size: size))
    }
}

extension View {
    /// Applies app-wide paragraph styling that scales with window size.
    /// - Parameter baseSize: The base font size used at ~800pt window width. Defaults to 15.
    func appParagraph(baseSize: CGFloat = 15) -> some View {
        modifier(ParagraphTextStyle(baseSize: baseSize))
    }
}

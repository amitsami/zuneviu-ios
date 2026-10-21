import SwiftUI

// The real system accessibility settings are always respected. Explicit DEBUG
// launch overrides let UI tests cover reduced motion/transparency and large text
// without changing the user's device or adding fake settings to release builds.
struct AppAccessibilitySettings: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var motion
    @Environment(\.accessibilityReduceTransparency) private var transparency
    @Environment(\.dynamicTypeSize) private var textSize
    func body(content: Content) -> some View {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        content
            .environment(\.accessibilityReduceMotion, motion || args.contains("--reduce-motion"))
            .environment(\.accessibilityReduceTransparency, transparency || args.contains("--reduce-transparency"))
            .environment(\.dynamicTypeSize, args.contains("--large-type") ? .accessibility2 : textSize)
        #else
        content
        #endif
    }
}

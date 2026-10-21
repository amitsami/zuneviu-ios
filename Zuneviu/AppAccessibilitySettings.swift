import SwiftUI

// The real system accessibility settings are always respected. Explicit DEBUG
// launch overrides let UI tests cover reduced motion/transparency and large text
// without changing the user's device or adding fake settings to release builds.
private struct TestReduceMotionKey: EnvironmentKey { static let defaultValue = false }
private struct TestReduceTransparencyKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var testReduceMotion: Bool {
        get { self[TestReduceMotionKey.self] } set { self[TestReduceMotionKey.self] = newValue }
    }
    var testReduceTransparency: Bool {
        get { self[TestReduceTransparencyKey.self] } set { self[TestReduceTransparencyKey.self] = newValue }
    }
}
struct AppAccessibilitySettings: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var motion
    @Environment(\.accessibilityReduceTransparency) private var transparency
    @Environment(\.dynamicTypeSize) private var textSize
    func body(content: Content) -> some View {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        content
            .environment(\.testReduceMotion, args.contains("--reduce-motion"))
            .environment(\.testReduceTransparency, args.contains("--reduce-transparency"))
            .environment(\.dynamicTypeSize, args.contains("--large-type") ? .accessibility2 : textSize)
        #else
        content
        #endif
    }
}

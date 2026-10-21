import SwiftUI
import UIKit

// Android-reference proportions, with an iPhone-safe lower edge. No full-width
// bar/background is painted: only the three floating capsule surfaces have glass.
enum DockLayout {
    static let horizontalInset: CGFloat = 12
    static let searchGap: CGFloat = 8
    static let baseHeight: CGFloat = 64
    static func bottomLift(safeArea: CGFloat) -> CGFloat { min(10, max(0, safeArea - 20)) }
}

struct GlassFooter: View {
    @Binding var selection: Int
    var select: (Int) -> Void
    var openSearch: () -> Void
    var openPlayer: () -> Void
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var preferences: PreferenceStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.testReduceMotion) private var testReduceMotion
    private var reduceMotion: Bool { systemReduceMotion || testReduceMotion || preferences.values.reduceAnimation }
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace
    @ScaledMetric(relativeTo: .body) private var scaledHeight = DockLayout.baseHeight
    private var height: CGFloat { min(96, max(DockLayout.baseHeight, scaledHeight)) }

    var body: some View {
        VStack(spacing: 8) {
            if let track = playback.current {
                GlassMiniPlayer(track: track, openPlayer: openPlayer)
                    .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: DockLayout.searchGap) {
                HStack(spacing: 0) {
                    tab("Home", icon: "house.fill", value: 0)
                    tab("Explore", icon: "safari", value: 1)
                    tab("Library", icon: "square.stack.fill", value: 2)
                }
                .padding(4)
                .frame(height: height)
                .modifier(CapsuleGlass())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("dock.tabs")
                Button(action: openSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: height, height: height)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressStyle())
                .modifier(CapsuleGlass(interactive: true))
                .accessibilityLabel("Search music")
                .accessibilityIdentifier("dock.search")
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: selection)
            .onChange(of: selection) { _ in UISelectionFeedbackGenerator().selectionChanged() }
        }
        .padding(.horizontal, DockLayout.horizontalInset)
        .padding(.top, 8).padding(.bottom, 2)
        .tint(.primary)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9), value: playback.current?.id)
        .alert("Something needs attention", isPresented: Binding(
            get: { library.error != nil || playback.error != nil },
            set: { if !$0 { library.error = nil; playback.error = nil } }
        )) {
            if playback.error != nil { Button("Retry playback") { playback.error = nil; playback.retry() } }
            Button("OK", role: .cancel) { library.error = nil; playback.error = nil }
        } message: { Text(library.error ?? playback.error ?? "") }
    }

    private func tab(_ title: String, icon: String, value: Int) -> some View {
        Button { select(value) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 21, weight: selection == value ? .semibold : .regular))
                Text(title).font(.caption.weight(selection == value ? .semibold : .medium)).lineLimit(1).minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity).frame(height: height - 8)
            .foregroundStyle(selection == value ? Color.primary : Color.primary.opacity(0.56))
            .background {
                if selection == value {
                    Capsule().fill(colorScheme == .dark ? Color.black.opacity(0.46) : Color.white.opacity(0.55))
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.055)).frame(height: 1).padding(.horizontal, 15)
                        }
                        .matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier("dock.tab.\(title.lowercased())")
        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
    }
}

struct GlassMiniPlayer: View {
    let track: Track
    var openPlayer: () -> Void
    @EnvironmentObject private var playback: PlaybackStore
    var body: some View {
        HStack(spacing: 4) {
            Button(action: openPlayer) {
                HStack(spacing: 10) {
                    Artwork(track: track, radius: 9).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Now playing: \(track.title)")
            Button { playback.toggle() } label: {
                Group {
                    if playback.isLoading { ProgressView().controlSize(.small) }
                    else { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 18, weight: .semibold)) }
                }.frame(width: 44, height: 44)
            }
            .accessibilityLabel(playback.isLoading ? "Cancel loading" : (playback.isPlaying ? "Pause" : "Play"))
            Button { playback.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
            }.accessibilityLabel("Next track")
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .modifier(CapsuleGlass())
        .accessibilityIdentifier("dock.miniplayer")
        .buttonStyle(GlassPressStyle())
    }
}

struct CapsuleGlass: ViewModifier {
    var interactive = false
    @EnvironmentObject private var preferences: PreferenceStore
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.testReduceTransparency) private var testReduceTransparency
    private var reduceTransparency: Bool { systemReduceTransparency || testReduceTransparency || !preferences.values.liquidGlass || preferences.values.reduceDynamicBlur }
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.94), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(.clear.interactive(interactive), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(scheme == .dark ? 0.16 : 0.3), lineWidth: 0.5))
            } else { fallback(content) }
            #else
            fallback(content)
            #endif
        }
    }
    private func fallback(_ content: Content) -> some View {
        content
            .background { Capsule().fill(.ultraThinMaterial) }
            .background { Capsule().fill(.black.opacity(scheme == .dark ? 0.10 : 0.025)) }
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.06), .white.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
struct GlassPressStyle: ButtonStyle {
    @EnvironmentObject private var preferences: PreferenceStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.testReduceMotion) private var testReduceMotion
    private var reduceMotion: Bool { systemReduceMotion || testReduceMotion || preferences.values.reduceAnimation }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

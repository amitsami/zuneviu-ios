import SwiftUI
import UIKit

// Keep newer navigation behavior where available without dropping iOS 15.
struct CompatibleNavigation<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    @ViewBuilder var body: some View {
        if #available(iOS 16, *) { NavigationStack { content } }
        else { NavigationView { content }.navigationViewStyle(.stack) }
    }
}
struct RouteLink<Destination: View, LabelView: View>: View {
    let destination: Destination
    let label: LabelView
    init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> LabelView) {
        self.destination = destination(); self.label = label()
    }
    init(_ title: String, @ViewBuilder destination: () -> Destination) where LabelView == Text {
        self.destination = destination(); self.label = Text(title)
    }
    var body: some View { NavigationLink(destination: destination) { label } }
}
struct IconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.action = action
    }
    var body: some View { Button(action: action) { Label(title, systemImage: systemImage) } }
}
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: Text? = nil
    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title; self.systemImage = systemImage; self.description = description
    }
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            if let description { description.font(.body).foregroundStyle(.secondary) }
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(24)
    }
    static func search(text: String) -> EmptyStateView {
        EmptyStateView("No results", systemImage: "magnifyingglass", description: Text("No music matches \"\(text)\"."))
    }
}
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

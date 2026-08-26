import SwiftUI

struct QuickHelpContent: Equatable {
    let title: String
    let detail: String
}

private struct QuickHelpModifier: ViewModifier {
    let title: String
    let detail: String

    func body(content: Content) -> some View {
        // Updating the shared observable model from `onHover` is unsafe when a
        // control changes identity under the pointer (for example Play -> Stop).
        // macOS 26 can dispatch the stale hover callback after SwiftUI has torn
        // down its actor executor, producing a null-executor crash. Native help
        // owns its tracking lifecycle and keeps the same guidance accessible.
        content.help("\(title) — \(detail)")
    }
}

extension View {
    func quickHelp(_ title: String, _ detail: String) -> some View {
        modifier(QuickHelpModifier(title: title, detail: detail))
    }
}

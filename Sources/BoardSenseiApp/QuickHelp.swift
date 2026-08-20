import SwiftUI

struct QuickHelpContent: Equatable {
    let title: String
    let detail: String
}

private struct QuickHelpModifier: ViewModifier {
    @EnvironmentObject private var model: AppModel
    let title: String
    let detail: String

    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                model.showQuickHelp(title: title, detail: detail)
            } else {
                model.clearQuickHelp()
            }
        }
    }
}

extension View {
    func quickHelp(_ title: String, _ detail: String) -> some View {
        modifier(QuickHelpModifier(title: title, detail: detail))
    }
}

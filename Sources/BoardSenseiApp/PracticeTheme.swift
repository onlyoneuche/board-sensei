import AppKit
import SwiftUI

/// Shared product colors. Blue is the single interactive accent throughout the app.
enum AppTheme {
    static let accent = Color(red: 0.20, green: 0.55, blue: 0.82)
    static let accentNSColor = NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.82, alpha: 1)
}

/// Neutral studio surfaces used inside the live Practice workspace.
enum PracticeTheme {
    static let accent = AppTheme.accent
    static let workspace = Color(nsColor: workspaceNSColor)
    static let sidebar = Color(nsColor: NSColor(calibratedWhite: 0.17, alpha: 1))
    static let toolbar = Color(nsColor: NSColor(calibratedWhite: 0.24, alpha: 1))
    static let panel = Color(nsColor: panelNSColor)
    static let raised = Color(nsColor: NSColor(calibratedWhite: 0.29, alpha: 1))
    static let inset = Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1))
    static let separator = Color.white.opacity(0.12)
    static let strongSeparator = Color.black.opacity(0.62)

    static let workspaceNSColor = NSColor(calibratedWhite: 0.135, alpha: 1)
    static let panelNSColor = NSColor(calibratedWhite: 0.205, alpha: 1)
    static let accentNSColor = AppTheme.accentNSColor
}

extension View {
    func practicePanel(cornerRadius: CGFloat = 7) -> some View {
        background(PracticeTheme.panel, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(PracticeTheme.separator, lineWidth: 1)
            }
    }
}

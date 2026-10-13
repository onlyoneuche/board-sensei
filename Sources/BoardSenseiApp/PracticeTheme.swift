import AppKit
import SwiftUI

/// One visual system for the studio, lesson workspace, and native Settings window.
enum AppTheme {
    static let accent = Color(red: 0.16, green: 0.43, blue: 0.68)
    static let accentNSColor = NSColor(calibratedRed: 0.16, green: 0.43, blue: 0.68, alpha: 1)
    static let canvas = Color(nsColor: surface(light: 0.93, dark: 0.105))
    static let surface = Color(nsColor: surface(light: 0.985, dark: 0.16))
    static let inset = Color(nsColor: surface(light: 0.955, dark: 0.125))
    static let elevated = Color(nsColor: surface(light: 1, dark: 0.205))
    static let line = Color(nsColor: surface(light: 0.80, dark: 0.32, highLight: 0.48, highDark: 0.62))
    static let ink = Color.primary
    static let radius: CGFloat = 4

    static func surface(
        light: CGFloat, dark: CGFloat,
        highLight: CGFloat? = nil, highDark: CGFloat? = nil
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ])
            let white: CGFloat
            switch match {
            case .darkAqua: white = dark
            case .accessibilityHighContrastDarkAqua: white = highDark ?? dark
            case .accessibilityHighContrastAqua: white = highLight ?? light
            default: white = light
            }
            return NSColor(calibratedWhite: white, alpha: 1)
        }
    }
}

enum PracticeTheme {
    static let accent = AppTheme.accent
    static let workspace = AppTheme.canvas
    static let sidebar = AppTheme.inset
    static let toolbar = AppTheme.surface
    static let panel = AppTheme.surface
    static let raised = AppTheme.elevated
    static let inset = AppTheme.inset
    static let separator = AppTheme.line
    static let strongSeparator = AppTheme.line
    static let workspaceNSColor = AppTheme.surface(light: 0.93, dark: 0.105)
    static let panelNSColor = AppTheme.surface(light: 0.985, dark: 0.16)
    static let accentNSColor = AppTheme.accentNSColor
}

extension View {
    func studioPanel(cornerRadius: CGFloat = AppTheme.radius) -> some View {
        background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppTheme.line, lineWidth: 1)
            }
    }

    func practicePanel(cornerRadius: CGFloat = AppTheme.radius) -> some View {
        studioPanel(cornerRadius: cornerRadius)
    }
}

struct StudioSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
    }
}

struct StudioPageHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudioSectionLabel(title: eyebrow)
            Text(title).font(.system(size: 32, weight: .medium))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Quiet musical linework, drawn locally rather than shipped as decorative imagery.
struct CourseArtwork: View {
    var technique = false
    var available = true

    var body: some View {
        Canvas { context, size in
            let ink = Color.primary.opacity(0.2)
            for row in 0..<5 {
                let y = size.height * 0.28 + CGFloat(row) * 9
                var line = Path()
                line.move(to: CGPoint(x: 12, y: y))
                line.addLine(to: CGPoint(x: size.width - 12, y: y))
                context.stroke(line, with: .color(ink), lineWidth: 0.5)
            }
            for index in 0..<18 {
                let x = 18 + CGFloat(index) * (size.width - 36) / 17
                let y = size.height * 0.48 + sin(Double(index) * (technique ? 0.72 : 1.15)) * (technique ? 20 : 12)
                let mark = CGRect(x: x - 3, y: y - 2.5, width: 6, height: 5)
                context.fill(Path(ellipseIn: mark), with: .color(index == 7 && available ? AppTheme.accent : .primary.opacity(available ? 0.6 : 0.24)))
                if technique {
                    context.fill(Path(ellipseIn: mark.offsetBy(dx: 0, dy: 20)), with: .color(.primary.opacity(0.22)))
                }
                var stem = Path()
                stem.move(to: CGPoint(x: x + 3, y: y))
                stem.addLine(to: CGPoint(x: x + 3, y: y - 17))
                context.stroke(stem, with: .color(ink), lineWidth: 0.75)
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: size.height - 7))
                tick.addLine(to: CGPoint(x: x, y: size.height - (index % 4 == 0 ? 14 : 10)))
                context.stroke(tick, with: .color(ink), lineWidth: 0.75)
            }
            var focus = Path()
            let x = 18 + 7 * (size.width - 36) / 17
            focus.move(to: CGPoint(x: x - 10, y: 10))
            focus.addLine(to: CGPoint(x: x - 10, y: 5))
            focus.addLine(to: CGPoint(x: x + 10, y: 5))
            focus.addLine(to: CGPoint(x: x + 10, y: 10))
            context.stroke(focus, with: .color(available ? AppTheme.accent : ink), lineWidth: 1)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A ruled separator echoes the reference's instrument-panel edges.
struct StudioRule: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(AppTheme.accent).frame(width: 24, height: 2)
            Rectangle().fill(AppTheme.line).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

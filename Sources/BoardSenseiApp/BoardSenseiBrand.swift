import AppKit
import SwiftUI

struct BoardSenseiMark: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.93))

            if let image = BoardSenseiBrandAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.07)
            } else {
                Image(systemName: "pianokeys")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BoardSenseiLockup: View {
    var markSize: CGFloat = 42

    var body: some View {
        HStack(spacing: 11) {
            BoardSenseiMark(size: markSize)
            VStack(alignment: .leading, spacing: 0) {
                Text("BOARD SENSEI")
                    .font(.headline.weight(.bold))
                Text("Learn it. Hear it. Play it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum BoardSenseiAppIcon {
    @MainActor
    static func make() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let brandImage = BoardSenseiBrandAsset.image
        return NSImage(size: size, flipped: false) { rect in
            let background = NSBezierPath(roundedRect: rect.insetBy(dx: 16, dy: 16), xRadius: 108, yRadius: 108)
            NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.93, alpha: 1).setFill()
            background.fill()

            brandImage?.draw(
                in: rect.insetBy(dx: 42, dy: 42),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
    }
}

@MainActor
private enum BoardSenseiBrandAsset {
    static let image: NSImage? = {
        guard let url = Bundle.module.url(
            forResource: "BoardSenseiLogo",
            withExtension: "png",
            subdirectory: "Brand"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }()
}

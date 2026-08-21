import AppKit
import SwiftUI

enum KeyboardIndicatorPreferences {
    static let expectedKey = "keyboardIndicatorExpectedColor"
    static let activeKey = "keyboardIndicatorActiveColor"

    static let defaultExpectedHex = "#338CD1"
    static let defaultActiveHex = "#65B5E8"

    static func color(from hex: String, fallback: String) -> Color {
        Color(nsColor: nsColor(from: hex) ?? nsColor(from: fallback) ?? .systemBlue)
    }

    static func hex(from color: Color, fallback: String) -> String {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return fallback }
        let red = Int((converted.redComponent * 255).rounded())
        let green = Int((converted.greenComponent * 255).rounded())
        let blue = Int((converted.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func contrastingText(for color: Color) -> Color {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.2126 * converted.redComponent
            + 0.7152 * converted.greenComponent
            + 0.0722 * converted.blueComponent
        return luminance > 0.58 ? .black : .white
    }

    private static func nsColor(from hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

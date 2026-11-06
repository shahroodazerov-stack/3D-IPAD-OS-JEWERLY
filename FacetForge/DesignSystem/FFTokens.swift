import Foundation
import SwiftUI

/// A colour in sRGB with enough numeric access for contrast tests.
///
/// SwiftUI's `Color` cannot be inspected after construction, so the design
/// system keeps its own value type and derives `Color` from it. That keeps the
/// semantic palette testable without a rendering pass.
struct FFColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF) / 255
        self.green = Double((hex >> 8) & 0xFF) / 255
        self.blue = Double(hex & 0xFF) / 255
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// WCAG 2.2 relative luminance.
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.2 contrast ratio, always >= 1.
    static func contrast(_ first: FFColor, _ second: FFColor) -> Double {
        let a = first.relativeLuminance
        let b = second.relativeLuminance
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// Semantic colours. Text roles are separate from fill roles so a colour that
/// is right as a button surface is not assumed to be legible as text.
enum FFPalette {
    static let canvas = FFColor(hex: 0x14161A)
    static let panel = FFColor(hex: 0x2A2E35)
    static let raised = FFColor(hex: 0x343A43)
    static let field = FFColor(hex: 0x1C2026)
    static let separator = FFColor(hex: 0x444B56)

    static let textPrimary = FFColor(hex: 0xF4F1EA)
    static let textSecondary = FFColor(hex: 0xBDB7AA)
    static let textTertiary = FFColor(hex: 0x9A9488)
    static let textAccent = FFColor(hex: 0xE0B872)
    static let textWarning = FFColor(hex: 0xF0937A)
    static let textSuccess = FFColor(hex: 0x7FC79B)
    static let textGem = FFColor(hex: 0x6FD0D6)

    static let accent = FFColor(hex: 0xC8A15A)
    static let accentPressed = FFColor(hex: 0x8C6F3F)
    static let gem = FFColor(hex: 0x1F6F78)
    static let warning = FFColor(hex: 0xC4553B)
    static let success = FFColor(hex: 0x3E7C59)
    static let onAccent = FFColor(hex: 0x14161A)
    static let onGem = FFColor(hex: 0xF4F1EA)

    /// Pairs the design system promises to keep legible. The test suite
    /// asserts each one against WCAG 2.2 AA for normal text.
    static let textPairs: [(String, FFColor, FFColor)] = [
        ("primary on canvas", textPrimary, canvas),
        ("primary on panel", textPrimary, panel),
        ("primary on field", textPrimary, field),
        ("secondary on canvas", textSecondary, canvas),
        ("secondary on panel", textSecondary, panel),
        ("secondary on field", textSecondary, field),
        ("tertiary on canvas", textTertiary, canvas),
        ("tertiary on panel", textTertiary, panel),
        ("tertiary on field", textTertiary, field),
        ("accent text on canvas", textAccent, canvas),
        ("accent text on panel", textAccent, panel),
        ("warning text on canvas", textWarning, canvas),
        ("warning text on panel", textWarning, panel),
        ("success text on canvas", textSuccess, canvas),
        ("success text on panel", textSuccess, panel),
        ("gem text on canvas", textGem, canvas),
        ("gem text on panel", textGem, panel),
        ("label on accent fill", onAccent, accent),
        ("label on gem fill", onGem, gem),
    ]
}

/// Type scale. Dynamic Type is intentional: sizes come from semantic styles,
/// while the monospaced face is reserved for dimensions.
enum FFType {
    static let display = Font.system(size: 34, weight: .semibold, design: .serif)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let section = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let label = Font.system(size: 14, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
}

enum FFSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum FFRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let pill: CGFloat = 999
}

struct FFShadow: Hashable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum FFElevation {
    static let panel = FFShadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 4)
    static let sheet = FFShadow(color: Color.black.opacity(0.42), radius: 24, x: 0, y: 10)
    static let toast = FFShadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 6)
}

/// The twelve primitives promised by Phase 3. The count is asserted by the
/// test suite so a primitive cannot be quietly removed from the gallery.
enum FFComponentCatalog {
    static let names = [
        "Button",
        "Chip",
        "Field",
        "Slider",
        "Segmented",
        "Sheet",
        "Panel",
        "List row",
        "Toast",
        "Tooltip",
        "Toolbar",
        "Empty state",
    ]
}

import SwiftUI

// MARK: - Hex color init

extension Color {
    /// Init from a hex string like "#8552F2" or "8552F2"
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        let scanned = Scanner(string: cleaned).scanHexInt64(&value)
        #if DEBUG
        assert(scanned && cleaned.count == 6,
               "Color(hex:) received invalid hex string: '\(hex)'")
        #endif

        guard scanned, cleaned.count == 6 else {
            // Release fallback: brand purple instead of invisible black
            self.init(red: 0.43, green: 0.34, blue: 1.0)
            return
        }

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value          & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Adaptive semantic colors
//
// All values switch between light and dark appearances automatically via
// UIColor(dynamicProvider:). Use these instead of hard-coded Color(hex:)
// so every surface looks correct on both white and black backgrounds.

enum AppColor {

    // MARK: Text

    /// High-contrast body text. Near-black on white; near-white on black.
    static let textPrimary   = Color(UIColor.adaptive(light: 0x111111, dark: 0xF0F0F0))

    /// Mid-gray — subtitles, deck names, secondary information.
    static let textSecondary = Color(UIColor.adaptive(light: 0x999999, dark: 0x9A9A9A))

    /// Slightly lighter mid-gray — used in paywall / timeline body copy.
    static let textMuted     = Color(UIColor.adaptive(light: 0x888888, dark: 0x9A9A9A))

    /// Light gray — timestamps, footers, helper hints.
    static let textTertiary  = Color(UIColor.adaptive(light: 0xBBBBBB, dark: 0x777777))

    /// Section-header uppercase label.
    static let sectionTitle  = Color(UIColor.adaptive(light: 0xAAAAAA, dark: 0x666666))

    // MARK: Chrome

    /// Disclosure chevron / right-arrow indicator.
    static let chevron       = Color(UIColor.adaptive(light: 0xCCCCCC, dark: 0x555555))

    /// Hairline separators between rows and in stats strip.
    static let separator     = Color(UIColor.adaptive(light: 0xE8E8E8, dark: 0x2A2A35))

    // MARK: Brand purple

    /// Interactive brand purple — buttons, selected borders, icon fills.
    /// Slightly brighter in dark mode for legibility on dark cards.
    static let brand         = Color(UIColor.adaptive(light: 0x6E56FF, dark: 0x9E70FF))

    /// Gradient end-stop purple.
    static let brandEnd      = Color(UIColor.adaptive(light: 0xA347FF, dark: 0xBF6AFF))
}

// MARK: - UIColor dynamic helpers

extension UIColor {
    /// Returns a dynamic color that resolves `lightHex` in light mode and
    /// `darkHex` in dark mode. Both values are 24-bit RGB (`0xRRGGBB`).
    static func adaptive(light lightHex: UInt32, dark darkHex: UInt32) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(rgb: darkHex)
                : UIColor(rgb: lightHex)
        }
    }

    convenience init(rgb hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >>  8) & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Appearance mode

/// User-selectable colour scheme preference stored in UserDefaults.
enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2

    var label: String {
        switch self {
        case .system: "Auto"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }

    /// Maps to SwiftUI's `ColorScheme`. `nil` means follow system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

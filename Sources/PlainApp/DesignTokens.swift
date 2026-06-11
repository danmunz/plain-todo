import SwiftUI

// MARK: - Color Tokens

/// All colors reference the Plain design token spec (docs/design/design-tokens.md).
/// Views should reference these tokens, never hardcoded colors.
enum PlainTokens {

    // MARK: Warm Gray Scale

    enum Gray {
        static let g50 = Color(light: .hex(0xFAF9F7), dark: .hex(0x1C1B19))
        static let g100 = Color(light: .hex(0xF5F3EF), dark: .hex(0x242320))
        static let g150 = Color(light: .hex(0xEDEAE4), dark: .hex(0x2C2A27))
        static let g200 = Color(light: .hex(0xE3E0D9), dark: .hex(0x383530))
        static let g300 = Color(light: .hex(0xD1CDC4), dark: .hex(0x4A4740))
        static let g400 = Color(light: .hex(0xA8A49B), dark: .hex(0x6B6760))
        static let g500 = Color(light: .hex(0x858179), dark: .hex(0x858179))
        static let g600 = Color(light: .hex(0x6B6760), dark: .hex(0xA8A49B))
        static let g700 = Color(light: .hex(0x504D47), dark: .hex(0xD1CDC4))
        static let g800 = Color(light: .hex(0x3D3B38), dark: .hex(0xE3E0D9))
        static let g900 = Color(light: .hex(0x2C2A28), dark: .hex(0xF5F3EF))
    }

    // MARK: App Accent

    /// Warm sienna accent — replaces system blue for selection, focus, and interactive elements.
    static let accent = Color(light: .hex(0x9B6A4A), dark: .hex(0xC8956E))

    // MARK: Semantic Surfaces

    enum Surface {
        static let canvas = Color(light: .hex(0xF0ECE4), dark: .hex(0x1C1B19))
        /// Slightly lighter than canvas; used as the top stop of the detail-pane gradient.
        static let canvasTop = Color(light: .hex(0xF6F2EA), dark: .hex(0x222120))
        static let sidebar = Color(light: .hex(0xE8E3D9), dark: .hex(0x242320))
        static let input = Color(light: .hex(0xFAF8F5), dark: .hex(0x2C2A27))
        static let hover = Color(light: .hex(0xE8E3D9), dark: .hex(0x2C2A27))
        static let selected = Color(light: .hex(0x9B6A4A, opacity: 0.12), dark: .hex(0xC8956E, opacity: 0.18))
        static let toast = Color(light: .hex(0x2C2A28), dark: .hex(0xF5F3EF))
        // quickAdd uses NSVisualEffectView in code, not a token color
    }

    // MARK: Semantic Text

    enum TextToken {
        static let primary = Color(
            light: .hex(0x2C2A28), dark: .hex(0xF5F3EF),
            lightHC: .hex(0x1A1918), darkHC: .hex(0xFAF9F7))
        static let secondary = Color(
            light: .hex(0x6B6760), dark: .hex(0xA8A49B),
            lightHC: .hex(0x3D3B38), darkHC: .hex(0xE3E0D9))
        static let muted = Color(
            light: .hex(0xA8A49B), dark: .hex(0x6B6760),
            lightHC: .hex(0x504D47), darkHC: .hex(0xD1CDC4))
        static let inverse = Gray.g50
    }

    // MARK: Borders & Separators

    enum Border {
        static let row = Color(
            light: .hex(0xDDD8CE), dark: .hex(0x383530),
            lightHC: .hex(0x8A8680), darkHC: .hex(0x7A7670))
        static let section = Color(
            light: .hex(0xCCC7BC), dark: .hex(0x4A4740),
            lightHC: .hex(0x6B6760), darkHC: .hex(0x8A8680))
        static let input = Color(
            light: .hex(0xD5D0C6), dark: .hex(0x383530),
            lightHC: .hex(0x6B6760), darkHC: .hex(0x8A8680))
        static let inputFocused = Color(
            light: .hex(0x9B6A4A, opacity: 0.60), dark: .hex(0xC8956E, opacity: 0.60),
            lightHC: .hex(0x7A4A2A), darkHC: .hex(0xE8AB7A))
    }

    // MARK: Selection & Focus

    enum Selection {
        static let bar = PlainTokens.accent
        static let bg = Color(
            light: .hex(0x9B6A4A, opacity: 0.10), dark: .hex(0xC8956E, opacity: 0.15),
            lightHC: .hex(0x9B6A4A, opacity: 0.22), darkHC: .hex(0xC8956E, opacity: 0.30))
        static let sidebarBg = Color(
            light: .hex(0x9B6A4A, opacity: 0.12), dark: .hex(0xC8956E, opacity: 0.18),
            lightHC: .hex(0x9B6A4A, opacity: 0.25), darkHC: .hex(0xC8956E, opacity: 0.35))
    }

    // MARK: Syntax Highlighting

    enum Syntax {
        static let project = Color(light: .hex(0x147A64), dark: .hex(0x4DD4AF))
        static let context = Color(light: .hex(0x6241A0), dark: .hex(0xB598E8))
        static let keyValue = Color(light: .hex(0x7A7670), dark: .hex(0x858179))
        static let date = Color(light: .hex(0x7A7670), dark: .hex(0x858179))
    }

    // MARK: Priority Colors

    enum Priority {
        static let a = Color(light: .hex(0xC42B18), dark: .hex(0xF06950))
        static let b = Color(light: .hex(0xAA7D00), dark: .hex(0xDAA832))
        static let c = Color(light: .hex(0x2E6BA4), dark: .hex(0x6FA8DC))
        static let low = Gray.g400

        static let aBg = Color(light: .hex(0xC42B18, opacity: 0.12), dark: .hex(0xF06950, opacity: 0.14))
        static let bBg = Color(light: .hex(0xAA7D00, opacity: 0.12), dark: .hex(0xDAA832, opacity: 0.14))
        static let cBg = Color(light: .hex(0x2E6BA4, opacity: 0.12), dark: .hex(0x6FA8DC, opacity: 0.14))
        static let lowBg = Color(light: .hex(0xD1CDC4, opacity: 0.30), dark: .hex(0x4A4740, opacity: 0.30))
    }

    // MARK: Status & Feedback

    enum Status {
        static let overdue = Priority.a
        static let today = Syntax.project
        static let completed = Color(light: .hex(0x147A64), dark: .hex(0x4DD4AF))
        static let conflict = Priority.b
        static let success = Syntax.project
        static let destructive = Priority.a
    }

    // MARK: Search

    enum Search {
        static let highlight = Color(light: .hex(0xC99D45, opacity: 0.25), dark: .hex(0xDAA832, opacity: 0.30))
    }
}

// MARK: - Typography Tokens

enum PlainType {
    // -- Named font helpers --
    private static func charter(size: CGFloat) -> Font {
        .custom("Charter Roman", size: size)
    }

    private static func charterBold(size: CGFloat) -> Font {
        .custom("Charter Bold", size: size)
    }

    private static func charterItalic(size: CGFloat) -> Font {
        .custom("Charter Italic", size: size)
    }

    private static func didot(size: CGFloat) -> Font {
        .custom("Didot", size: size)
    }

    private static func didotBold(size: CGFloat) -> Font {
        .custom("Didot-Bold", size: size)
    }

    private static func didotItalic(size: CGFloat) -> Font {
        .custom("Didot-Italic", size: size)
    }

    // -- App chrome (SF Pro — native, functional) --
    static let windowTitle = Font.system(size: 13, weight: .semibold)
    static let sidebarSection = Font.system(size: 10, weight: .heavy)
    static let sidebarLabel = Font.system(size: 13, weight: .medium)
    static let sidebarCount = Font.system(size: 12, weight: .regular)
    static let groupHeader = Font.system(size: 11, weight: .heavy)
    static let priorityBadge = Font.system(size: 11, weight: .bold)
    static let inputHint = Font.system(size: 11, weight: .regular)
    static let statusBar = Font.system(size: 11, weight: .regular)
    static let scratchPad = Font.system(size: 13, design: .monospaced)
    static let taskMeta = Font.system(size: 12, weight: .regular)

    // -- Content (Charter — crisp screen serif by Matthew Carter) --
    static let taskBody = charter(size: 14)
    static let taskTags = charterBold(size: 14)
    static let taskDueDate = Font.system(size: 11, weight: .medium)
    static let taskDueDateUrgent = Font.system(size: 11, weight: .medium).italic()
    static let inputBar = charter(size: 14)
    static let inputPlaceholder = charterItalic(size: 14)
    static let toastMessage = charterItalic(size: 12)
    static let emptyState = charterItalic(size: 15)

    // -- Display (Didot — editorial, high-contrast) --
    static let onboardingHeading = Font.custom("Didot", size: 56)
    static let onboardingBody = charter(size: 14)
    static let mastheadTitle = didotBold(size: 30)
    static let mastheadDate = Font.system(size: 10, weight: .semibold)
    static let mastheadMeta = charterItalic(size: 13)
    static let panelTitle = didotBold(size: 20)
    static let emptyStateTitle = didotItalic(size: 22)
    static let colophon = Font.system(size: 9.5, weight: .medium)
    static let priorityGlyph = charterBold(size: 13)

    // -- Icons (SF Pro, sized for SF Symbols) --
    static let iconSmall = Font.system(size: 11, weight: .bold)
    static let iconMedium = Font.system(size: 14)
    static let iconLarge = Font.system(size: 16, weight: .medium)

    /// Returns a scaled taskBody font at the user's chosen size.
    static func taskBody(size: Double) -> Font {
        charter(size: size)
    }

    /// Returns a scaled taskTags font at the user's chosen size.
    static func taskTags(size: Double) -> Font {
        charterBold(size: size)
    }

    /// Returns a scaled inputBar font at the user's chosen size.
    static func inputBar(size: Double) -> Font {
        charter(size: size)
    }

    /// Returns a scaled emptyState font at the user's chosen size.
    static func emptyState(size: Double) -> Font {
        charterItalic(size: size)
    }
}

// MARK: - Spacing Tokens

enum Spacing {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 32
}

// MARK: - Measurement Tokens

enum Measurement {
    static let sidebarWidthDefault: CGFloat = 220
    static let sidebarWidthMin: CGFloat = 180
    static let sidebarWidthMax: CGFloat = 300
    static let taskRowMinHeight: CGFloat = 44
    static let inputBarHeight: CGFloat = 48
    static let statusBarHeight: CGFloat = 28
    static let completionCircleDiameter: CGFloat = 18
    static let priorityBadgeHeight: CGFloat = 22
    static let selectionBarWidth: CGFloat = 3
    static let groupHeaderHeight: CGFloat = 28
    static let sidebarItemHeight: CGFloat = 28
    static let rowSeparatorThickness: CGFloat = 0.5
    static let searchOverlayWidth: CGFloat = 400
}

// MARK: - Corner Radius Tokens

enum Radius {
    static let none: CGFloat = 0
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
}

// MARK: - Shadow Tokens

enum PlainShadow {
    static func toast(_ scheme: ColorScheme) -> some ShapeStyle {
        scheme == .dark
            ? Color.black.opacity(0.3)
            : Color(hex: 0x2C2A28, opacity: 0.12)
    }

    static let toastRadius: CGFloat = 8
    static let toastY: CGFloat = 2

    static func search(_ scheme: ColorScheme) -> some ShapeStyle {
        scheme == .dark
            ? Color.black.opacity(0.4)
            : Color(hex: 0x2C2A28, opacity: 0.15)
    }

    static let searchRadius: CGFloat = 20
    static let searchY: CGFloat = 4

    static func quickAdd(_ scheme: ColorScheme) -> some ShapeStyle {
        scheme == .dark
            ? Color.black.opacity(0.5)
            : Color(hex: 0x2C2A28, opacity: 0.2)
    }

    static let quickAddRadius: CGFloat = 32
    static let quickAddY: CGFloat = 8

    static func drag(_ scheme: ColorScheme) -> some ShapeStyle {
        scheme == .dark
            ? Color.black.opacity(0.35)
            : Color(hex: 0x2C2A28, opacity: 0.15)
    }

    static let dragRadius: CGFloat = 12
    static let dragY: CGFloat = 4
}

// MARK: - Opacity Tokens

enum Opacity {
    static let completedRow: Double = 0.45
    static let hoverMenu: Double = 0.7
    static let disabledControl: Double = 0.4
    static let dragPlaceholder: Double = 0.3
    static let searchDimmed: Double = 0.35
    static let highlightRow: Double = 0.08
    static let bannerBg: Double = 0.10
}

// MARK: - Animation Tokens

enum Anim {
    static let fast: Double = 0.12
    static let normal: Double = 0.2
    static let slow: Double = 0.3
    static let pulseDuration: Double = 1.0

    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    static let completionDelay: Double = 0.4
    static let completionCircle = Animation.spring(response: 0.2, dampingFraction: 0.6)
    static let completionStrike: Double = 0.25
    static let completionDim: Double = 0.2

    static let toastIn: Double = 0.2
    static let toastLinger: Double = 4.0
    static let toastOut: Double = 0.15

    static let searchIn: Double = 0.15
    static let searchOut: Double = 0.12

    static let quickAddIn: Double = 0.15
    static let quickAddOut: Double = 0.12

    /// Returns the appropriate animation for the given duration, or instant if reduce-motion is on.
    static func animation(_ duration: Double, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: duration)
    }

    /// Convenience: fast ease-out, respecting reduce-motion.
    static func fastEaseOut(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: fast)
    }

    /// Convenience: normal ease-in-out, respecting reduce-motion.
    static func normalEaseInOut(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: normal)
    }

    /// Convenience: slow ease-in-out, respecting reduce-motion.
    static func slowEaseInOut(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: slow)
    }
}

// MARK: - Tracking Constants (letterspacing)

enum Tracking {
    static let sidebarSection: CGFloat = 2.0
    static let groupHeader: CGFloat = 1.5
    static let onboardingHeading: CGFloat = 0.5
    static let mastheadDate: CGFloat = 1.8
    static let colophon: CGFloat = 1.4
}

// MARK: - Color Helpers

extension Color {
    /// Create a color from a hex integer value (e.g., 0xF5F3EF).
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// Create an adaptive color that resolves differently in light and dark modes.
    init(light: ColorSpec, dark: ColorSpec) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let spec = isDark ? dark : light
            return spec.nsColor
        })
    }

    /// Create an adaptive color with an optional high-contrast override per mode.
    init(light: ColorSpec, dark: ColorSpec, lightHC: ColorSpec, darkHC: ColorSpec) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let isHC = appearance.bestMatch(from: [
                .accessibilityHighContrastAqua,
                .accessibilityHighContrastDarkAqua,
                .aqua,
                .darkAqua
            ])?.rawValue.contains("HighContrast") ?? false
            if isDark {
                return isHC ? darkHC.nsColor : dark.nsColor
            } else {
                return isHC ? lightHC.nsColor : light.nsColor
            }
        })
    }
}

/// A lightweight descriptor for building adaptive colors without nesting closures.
struct ColorSpec {
    let nsColor: NSColor

    static func hex(_ value: UInt, opacity: Double = 1.0) -> ColorSpec {
        ColorSpec(nsColor: NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: CGFloat(opacity)
        ))
    }

    /// System accent color at a given opacity. Resolved at draw time.
    static func accentDynamic(opacity: Double) -> ColorSpec {
        ColorSpec(nsColor: NSColor.controlAccentColor.withAlphaComponent(CGFloat(opacity)))
    }
}

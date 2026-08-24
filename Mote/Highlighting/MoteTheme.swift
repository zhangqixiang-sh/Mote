import AppKit

/// 主题风格:跟随系统外观自动切换
enum MoteThemeStyle {
    case light
    case dark

    init(appearance: NSAppearance?) {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        self = isDark ? .dark : .light
    }
}

/// 主题工厂:按风格产出主题实例
enum MoteThemeFactory {
    static func theme(for style: MoteThemeStyle) -> SourceCodeTheme {
        switch style {
        case .light: return MoteLightTheme()
        case .dark: return MoteDarkTheme()
        }
    }
}

// MARK: - 浅色主题(VS Code Light+ 配色)

struct MoteLightTheme: SourceCodeTheme {

    let font = NSFont(name: "Menlo", size: 13)
        ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    let backgroundColor = NSColor.white

    let lineNumbersStyle: LineNumbersStyle? = LineNumbersStyle(
        font: NSFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11),
        textColor: NSColor(calibratedWhite: 0.43, alpha: 1)
    )

    let gutterStyle = GutterStyle(
        backgroundColor: NSColor(calibratedWhite: 0.96, alpha: 1),
        minimumWidth: 44
    )

    func color(for syntaxColorType: SourceCodeTokenType) -> NSColor {
        switch syntaxColorType {
        case .plain:            return NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.09, alpha: 1) // #171717
        case .keyword:          return NSColor(calibratedRed: 0.69, green: 0.00, blue: 0.86, alpha: 1) // #AF00DB
        case .string:           return NSColor(calibratedRed: 0.64, green: 0.08, blue: 0.08, alpha: 1) // #A31515
        case .number:           return NSColor(calibratedRed: 0.04, green: 0.53, blue: 0.34, alpha: 1) // #098658
        case .comment:          return NSColor(calibratedRed: 0.00, green: 0.50, blue: 0.00, alpha: 1) // #008000
        case .identifier:       return NSColor(calibratedRed: 0.15, green: 0.50, blue: 0.60, alpha: 1) // #267F99
        case .editorPlaceholder: return backgroundColor
        }
    }
}

// MARK: - 深色主题(VS Code Dark+ 配色)

struct MoteDarkTheme: SourceCodeTheme {

    let font = NSFont(name: "Menlo", size: 13)
        ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    let backgroundColor = NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1) // #1E1E1E

    let lineNumbersStyle: LineNumbersStyle? = LineNumbersStyle(
        font: NSFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11),
        textColor: NSColor(calibratedWhite: 0.45, alpha: 1)
    )

    let gutterStyle = GutterStyle(
        backgroundColor: NSColor(calibratedRed: 0.145, green: 0.145, blue: 0.145, alpha: 1), // #252526
        minimumWidth: 44
    )

    func color(for syntaxColorType: SourceCodeTokenType) -> NSColor {
        switch syntaxColorType {
        case .plain:            return NSColor(calibratedRed: 0.83, green: 0.83, blue: 0.83, alpha: 1) // #D4D4D4
        case .keyword:          return NSColor(calibratedRed: 0.77, green: 0.53, blue: 0.75, alpha: 1) // #C586C0
        case .string:           return NSColor(calibratedRed: 0.81, green: 0.57, blue: 0.47, alpha: 1) // #CE9178
        case .number:           return NSColor(calibratedRed: 0.71, green: 0.81, blue: 0.66, alpha: 1) // #B5CEA8
        case .comment:          return NSColor(calibratedRed: 0.42, green: 0.60, blue: 0.33, alpha: 1) // #6A9955
        case .identifier:       return NSColor(calibratedRed: 0.61, green: 0.80, blue: 1.00, alpha: 1) // #9CDCFE
        case .editorPlaceholder: return backgroundColor
        }
    }
}

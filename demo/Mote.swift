// Mote.swift — Mote 编辑器示例代码
import AppKit

/// 轻量文本编辑器主窗口
final class EditorWindowController: NSWindowController {

    private let textView = NSTextView()

    func open(url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        textView.string = text
        window?.title = url.lastPathComponent
    }
}

enum Theme {
    case light, dark

    var background: NSColor {
        switch self {
        case .light: return .white
        case .dark:  return NSColor(white: 0.12, alpha: 1)
        }
    }
}

let maxRecentFiles = 30
let version = "0.2.0"

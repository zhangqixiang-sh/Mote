import AppKit
import SwiftUI

/// Mote 文档模型:NSDocument 骨架
///
/// 基于 NSDocument 架构,天然获得打开/保存/自动保存/多窗口等 macOS
/// 文档型应用能力。后续里程碑在此基础上接入语法高亮、编码检测等。
final class MoteDocument: NSDocument {

    /// 文档内容(明文阶段直接使用;M2 接入高亮后改为自定义 NSTextStorage)
    private var text = ""

    // MARK: - 窗口

    override func makeWindowControllers() {
        let rootView = EditorView(document: self)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 880, height: 640))
        window.title = displayName
        let windowController = NSWindowController(window: window)
        addWindowController(windowController)
    }

    // MARK: - 文件读写(明文骨架,M1 验收目标)

    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "MoteDocumentError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法以 UTF-8 解码文件内容(编码检测将在后续里程碑实现)"]
            )
        }
        text = string
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(text.utf8)
    }
}

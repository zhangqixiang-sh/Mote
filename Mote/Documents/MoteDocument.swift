import AppKit
import SwiftUI

/// Mote 文档模型:NSDocument 承载
///
/// 基于 NSDocument 架构,天然获得打开/保存/多窗口等 macOS 文档型应用
/// 能力。M2 起编辑内容由 Sourceful 词法分析器按文件类型高亮。
/// 注意:必须用 @objc 固定运行时类名。Info.plist 的 NSDocumentClass 为
/// "MoteDocument",NSDocumentController 通过 NSClassFromString 查找;
/// Swift 类默认带模块前缀(Mote.MoteDocument),不加 @objc 会查找失败,
/// 导致所有文档都无法打开("cannot open files in the ... format")。
@objc(MoteDocument)
final class MoteDocument: NSDocument {

    /// 文档全文(编辑区唯一事实来源,EditorView 委托回写)
    var text = ""

    /// 按文件扩展名确定的词法分析器(文档生命周期内缓存)
    private var cachedLexer: Lexer?

    var lexer: Lexer {
        if let cachedLexer = cachedLexer {
            return cachedLexer
        }
        let resolved = LanguageDetection.lexer(forFileExtension: fileURL?.pathExtension)
        cachedLexer = resolved
        return resolved
    }

    // MARK: - 文档类型

    /// 告诉 NSDocumentController 本类可以读取/写入所有注册过的 UTI。
    /// 这里返回与 Info.plist 中 `CFBundleDocumentTypes` 完全一致的列表，
    /// 避免 Launch Services 无法把文件路由到 MoteDocument。
    override class var readableTypes: [String] {
        return [
            "public.plain-text",
            "public.text",
            "public.source-code",
            "public.json",
            "public.swift-source",
            "public.c-source",
            "public.c-header",
            "public.c-plus-plus-source",
            "public.c-plus-plus-header",
            "public.objective-c-source",
            "public.objective-c-plus-plus-source",
            "public.csharp-source",
            "public.go-source",
            "public.rust-source",
            "public.python-script",
            "public.javascript-source",
            "public.ruby-script",
            "public.php-script",
            "public.shell-script",
            "public.sql",
            "public.html",
            "public.xml",
            "public.css",
            "public.plist",
            "public.composite-content",
            "com.mote.yaml",
            "com.mote.markdown",
            "com.mote.toml",
            "com.mote.typescript",
            "com.mote.java",
            "com.mote.cpp",
            "com.mote.objc",
            "com.mote.csharp",
        ]
    }

    override class var writableTypes: [String] {
        return readableTypes
    }

    // MARK: - 窗口

    override func makeWindowControllers() {
        let rootView = EditorView(document: self)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 880, height: 640))
        window.title = displayName
        // 标题栏保持系统默认不透明样式:
        // - 标题栏是天然统一的整体颜色(系统材质,自动跟随深浅色外观)
        // - 编辑区内容不会延伸到标题栏后面,gutter 行号区背景与内容区的
        //   分界线从标题栏下沿才开始,不会"通到顶"
        // - 拖动/双击最大化/红黄绿交通灯全部走系统原生路径,零维护成本
        // 去掉标题栏与内容区之间的默认分隔线,让两者无缝衔接
        window.titlebarSeparatorStyle = .none
        let windowController = NSWindowController(window: window)
        addWindowController(windowController)
    }

    // MARK: - 文件读写(明文 UTF-8;编码检测将在 M4 实现)

    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "MoteDocumentError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法以 UTF-8 解码文件内容(编码检测将在 M4 实现)"]
            )
        }
        text = string
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(text.utf8)
    }
}

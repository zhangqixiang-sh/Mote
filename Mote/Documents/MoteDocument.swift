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

    /// 统一预览面板的类型(PRD 决策 4:按文件类型路由)
    enum PreviewKind {
        /// Markdown:由 MarkdownRenderer 渲染
        case markdown
        /// SVG / HTML:原样静态渲染(禁 JS)
        case webDocument
    }

    /// 是否提供右侧分栏预览(M3 起;SVG/HTML 预览自 M4 起)
    var isPreviewable: Bool { previewKind != nil }

    var previewKind: PreviewKind? {
        switch fileURL?.pathExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd":
            return .markdown
        case "svg", "svgz", "html", "htm", "xhtml":
            return .webDocument
        default:
            return nil
        }
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
        // Markdown 文档默认带右侧预览分栏,初始窗口加宽
        window.setContentSize(NSSize(width: isPreviewable ? 1120 : 880, height: 640))
        window.title = displayName
        // 标题栏透明沉浸式:
        // - .fullSizeContentView + titlebarAppearsTransparent:内容视图
        //   真正延伸到标题栏后面,标题栏材质层被内容覆盖(沉浸式)
        // - 为避免 gutter 行号区背景色"伸入"标题栏,顶部 28pt 用
        //   编辑区背景色覆盖(HeaderOverlayView,颜色跟随主题),
        //   使标题栏高度部分的颜色与文件区背景完全一致
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        installHeaderOverlay(in: window)
        let windowController = NSWindowController(window: window)
        addWindowController(windowController)
    }

    /// 在窗口框架层(NSThemeFrame)顶部放一个不透明的 header 覆盖层
    ///
    /// 背景:透明标题栏下,标题栏区域由系统材质层(NSVisualEffectView)
    /// 填充,其渲染层级高于 window.contentView 的任何子视图——把覆盖层
    /// 加进 contentView 会被材质层盖住;NSTitlebarAccessoryViewController
    /// 在无 toolbar 的窗口上也不显示。因此把覆盖视图直接加到
    /// contentView.superview(NSThemeFrame,即窗口框架层)并 positioned
    /// .above,盖住材质层。
    ///
    /// 关键:覆盖层会同时盖住交通灯按钮(_NSThemeCloseWidget 等在
    /// NSTitlebarContainerView 内),所以覆盖层加完后再把
    /// NSTitlebarContainerView 提升到覆盖层之上,保证红黄绿按钮可见。
    ///
    /// 颜色 = 当前主题的编辑区背景色(`MoteThemeFactory`),与文件区背景
    /// 完全一致,并随系统深浅色外观自动切换。作用:
    /// - 挡住系统标题栏材质层,标题栏高度部分呈现与文件区一致的背景色
    /// - gutter 行号区背景不会伸入标题栏(编辑区内容本就在标题栏下方)
    ///
    /// 高度:不写死,动态跟随标题栏实际高度
    /// (`window.frame.height - window.contentLayoutRect.height`)。
    /// 加了 toolbar(如预览开关)后标题栏会被撑高,固定高度会盖不住,
    /// 导致 gutter 行号背景从标题栏下沿漏出来。
    ///
    /// `HeaderOverlayView.hitTest` 恒返回 nil:标题栏拖动/双击最大化/
    /// 红黄绿交通灯等系统手势全部走 NSWindow 原生路径,覆盖层仅视觉遮挡。
    private func installHeaderOverlay(in window: NSWindow) {
        guard let container = window.contentView?.superview else { return }

        let overlay = HeaderOverlayView(frame: .zero)
        overlay.bind(window: window)
        // 窗口 resize 时:宽度跟随,顶部吸附(y 由 updateHeight 统一重算)
        overlay.autoresizingMask = [.width, .minYMargin]
        container.addSubview(overlay, positioned: .above, relativeTo: nil)
        overlay.updateHeight()

        // 覆盖层加完后,把标题栏容器(含交通灯按钮)提升到覆盖层之上,
        // 避免红黄绿按钮被覆盖层挡住
        if let titlebar = Self.findView(named: "NSTitlebarContainerView", in: container) {
            container.addSubview(titlebar, positioned: .above, relativeTo: overlay)
        }

        // SwiftUI toolbar 在窗口布局后由 NSHostingView 挂载,会再撑高
        // 标题栏;延迟一帧刷新兜底,确保覆盖层高度与最终标题栏一致
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak overlay] in
            overlay?.updateHeight()
        }
    }

    /// 按类名递归查找视图(用于定位私有类 NSTitlebarContainerView)
    private static func findView(named className: String, in view: NSView) -> NSView? {
        if String(describing: type(of: view)) == className {
            return view
        }
        for subview in view.subviews {
            if let found = findView(named: className, in: subview) {
                return found
            }
        }
        return nil
    }

    /// 标题栏高度不再硬编码:由 HeaderOverlayView.updateHeight() 依据
    /// `window.frame.height - window.contentLayoutRect.height` 动态计算
    ///
    // MARK: - 自动保存(M4)

    /// 启用系统自动保存:编辑后自动写回原文件,无需手动 ⌘S
    override class var autosavesInPlace: Bool { true }

    // MARK: - 文件读写(编码自动检测:M4 实现)

    /// 当前文档编码(读入时检测,保存时按原编码写回;新建文档默认 UTF-8)
    private(set) var encoding: String.Encoding = .utf8

    /// 读入时是否带 BOM(保存时保留)
    private var hasBOM = false

    override func read(from data: Data, ofType typeName: String) throws {
        let result = try TextEncodingDetector.decode(data)
        text = result.text
        encoding = result.encoding
        hasBOM = result.hasBOM
    }

    override func data(ofType typeName: String) throws -> Data {
        TextEncodingDetector.encode(text, encoding: encoding, hasBOM: hasBOM)
    }
}

// MARK: - 辅助视图

/// 顶部 header 覆盖层:纯色遮挡 + 不拦截事件
///
/// - 颜色 = 当前主题的编辑区背景色(`MoteThemeFactory`),与文件区背景
///   完全一致;`viewDidChangeEffectiveAppearance` 在系统深浅色外观切换
///   时自动更新
/// - 高度动态 = 标题栏 + toolbar 实际高度
///   (`window.frame.height - window.contentLayoutRect.height`),不写死:
///   加 toolbar(预览开关)后标题栏会被撑高,固定高度会盖不住,导致
///   gutter 行号区背景从标题栏下沿漏出。监听窗口 resize / 全屏切换
///   时重算,覆盖层始终盖满整个标题栏区域
/// - 作用:挡住透明标题栏透出的 gutter 行号区背景(#252526),避免其
///   伸入标题栏;标题栏高度部分呈现与文件区一致的沉浸式背景
/// - `hitTest` 恒返回 nil:标题栏拖动/双击最大化/红黄绿交通灯等系统
///   手势全部走 NSWindow 原生路径,覆盖层只负责视觉遮挡
private final class HeaderOverlayView: NSView {

    /// 所跟踪的窗口(用于读取标题栏实际高度)
    private weak var trackedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateBackgroundColor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        updateBackgroundColor()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// 绑定窗口并监听布局变化:resize / 全屏进出都会改变标题栏高度
    func bind(window: NSWindow) {
        trackedWindow = window
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                self?.updateHeight()
            }
        }
    }

    /// 重算覆盖层高度与位置:顶部吸附,高度 = 标题栏 + toolbar 实际高度
    func updateHeight() {
        guard let window = trackedWindow, let superview = superview else { return }
        // 标题栏高度 = 窗口高 - 内容布局区高(fullSizeContentView 下
        // contentLayoutRect 顶部即标题栏下沿;toolbar 会撑高标题栏)
        let titlebarHeight = max(0, window.frame.height - window.contentLayoutRect.height)
        frame = NSRect(
            x: 0,
            y: superview.bounds.height - titlebarHeight,
            width: superview.bounds.width,
            height: titlebarHeight
        )
    }

    /// 系统深浅色外观切换时,颜色跟随当前主题的编辑区背景色
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    /// 不拦截任何鼠标事件,避免吃掉标题栏系统手势
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func updateBackgroundColor() {
        let style = MoteThemeStyle(appearance: effectiveAppearance)
        let theme = MoteThemeFactory.theme(for: style)
        layer?.backgroundColor = theme.backgroundColor.cgColor
    }
}

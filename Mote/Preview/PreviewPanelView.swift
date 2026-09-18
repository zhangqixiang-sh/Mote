import SwiftUI
import WebKit

/// 统一预览面板(只读 WKWebView)
///
/// 架构约定(PRD):预览 = 只读 WKWebView,懒加载、按需创建、关闭即释放;
/// 按文件类型路由:`markdown` → MarkdownRenderer 渲染,`webDocument`
/// (SVG/HTML)→ 原样静态渲染。
/// - 懒加载/按需创建:仅当文档可预览且预览开关打开时,SwiftUI 才实例化
///   本视图;普通代码文件完全不创建 WebView
/// - 关闭即释放:开关关闭后视图从层级移除,WKWebView 随之释放
/// - 禁 JS:`allowsContentJavaScript = false`(Markdown 预览与 SVG/HTML
///   均为静态渲染,省内存、杜絕脚本注入面)
/// - 深浅色:Markdown 用 `prefers-color-scheme` 媒体查询跟随系统;
///   SVG/HTML 原样渲染,保留文件自身样式
/// - 边输入边刷新:`updateNSView` 内做 ~250ms 防抖,停止输入后才重渲染
/// - 相对资源:`loadHTMLString` 的 baseURL 指向文档所在目录
struct PreviewPanelView: NSViewRepresentable {

    /// 预览类型(MoteDocument.PreviewKind)
    let kind: MoteDocument.PreviewKind

    /// 当前文档源文本(每次编辑后由 EditorView 传入)
    let content: String

    /// 文档文件 URL(取所在目录作为 baseURL,支持相对路径图片等资源)
    let fileURL: URL?

    /// 编辑区 ↔ 预览滚动联动控制器(EditorView 创建并共享给编辑桥)
    let sync: PreviewScrollSync?

    /// Markdown 实时渲染上限。实测 1MB Markdown → HTML 约 0.8s、
    /// 3MB 约 2.4s(CoreFoundation 正则/字符串替换),若仍在主线程
    /// 首次建窗或输入防抖时执行,大文档会表现为"窗口卡死、预览不出"。
    /// 超过该阈值的 Markdown 不自动渲染全文,只显示轻量说明,保证编辑
    /// 主线程永远可用;阈值内仍保留边输入边刷新。
    /// 2026-09-18 按用户要求收紧到 256KB(源文本 UTF-8 字节)。
    static let liveMarkdownRenderLimit = 256 * 1024

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 静态预览不需要 JS,关掉以省内存、杜絕脚本注入面
        // (页面脚本被禁,但原生 evaluateJavaScript 与 messageHandlers
        // 桥不受影响——滚动联动即用此通道,见 Coordinator)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.userContentController.add(context.coordinator, name: "moteScroll")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground") // 透明底,加载前不闪白
        webView.navigationDelegate = context.coordinator
        // 滚动联动接线:KVO 预览 contentView.bounds(原生接口,不依赖页面 JS)
        if let sync = sync {
            context.coordinator.bindScrollSync(sync, webView: webView)
        }
        // 首次创建不同步渲染:makeNSView 发生在主线程,大文档同步
        // MarkdownRenderer.render 会直接卡住窗口出现。统一走异步调度。
        context.coordinator.lastRenderedContent = content
        context.coordinator.scheduleRender(webView: webView,
                                           kind: kind,
                                           content: content,
                                           baseURL: fileURL?.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard content != context.coordinator.lastRenderedContent else { return }
        context.coordinator.lastRenderedContent = content
        context.coordinator.scheduleRender(webView: webView,
                                           kind: kind,
                                           content: content,
                                           baseURL: fileURL?.deletingLastPathComponent())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - 渲染

    /// 大文档 Markdown 的轻量说明页(不跑 MarkdownRenderer,常量耗时)
    private static func largeMarkdownNoticeHTML(sourceBytes: Int) -> String {
        let mb = String(format: "%.1f", Double(sourceBytes) / 1_000_000)
        let limitKB = liveMarkdownRenderLimit / 1024
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body {
            font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
            font-size: 14px;
            line-height: 1.65;
            padding: 28px 24px;
            margin: 0;
            color: #6a737d;
            background: transparent;
        }
        h2 { margin: 0 0 10px; font-size: 16px; color: #171717; }
        p { margin: 0 0 8px; }
        code {
            font-family: Menlo, monospace;
            background: rgba(27, 31, 35, 0.06);
            border-radius: 4px;
            padding: 0.1em 0.35em;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #8b949e; }
            h2 { color: #d4d4d4; }
            code { background: rgba(255, 255, 255, 0.1); }
        }
        </style>
        </head>
        <body>
        <h2>已暂停实时预览</h2>
        <p>当前 Markdown 约 <code>\(mb) MB</code>,超过自动预览上限 <code>\(limitKB) KB</code>。</p>
        <p>为避免大文档渲染阻塞编辑,这份文档不会自动渲染到预览栏;编辑、保存与代码高亮不受影响。</p>
        </body>
        </html>
        """
    }

    /// 组装待加载的 HTML(纯计算,可在后台队列调用)
    private static func makeHTML(kind: MoteDocument.PreviewKind, content: String) -> String {
        switch kind {
        case .markdown:
            let body = MarkdownRenderer.render(content)
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(markdownStylesheet)</style>
            </head>
            <body>\(body)</body>
            </html>
            """
        case .webDocument:
            // SVG / HTML 原样渲染:保留文件自身结构与样式
            return content
        }
    }

    /// Markdown 预览样式:跟随系统深浅色(prefers-color-scheme)
    private static let markdownStylesheet = """
    :root {
        color-scheme: light dark;
    }
    body {
        font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
        font-size: 14px;
        line-height: 1.65;
        padding: 12px 20px 32px;
        margin: 0;
        word-wrap: break-word;
        color: #171717;
        background: #ffffff;
    }
    h1, h2 { border-bottom: 1px solid #e1e4e8; padding-bottom: 0.25em; }
    h1 { font-size: 1.7em; }
    h2 { font-size: 1.4em; }
    h3 { font-size: 1.2em; }
    code {
        font-family: Menlo, monospace;
        font-size: 0.92em;
        background: rgba(27, 31, 35, 0.06);
        border-radius: 4px;
        padding: 0.15em 0.35em;
    }
    pre {
        background: rgba(27, 31, 35, 0.05);
        border-radius: 6px;
        padding: 12px 14px;
        overflow-x: auto;
    }
    pre code { background: none; padding: 0; }
    blockquote {
        margin: 0;
        padding: 0 1em;
        color: #6a737d;
        border-left: 3px solid #dfe2e5;
    }
    table {
        border-collapse: collapse;
        margin: 0.8em 0;
    }
    th, td {
        border: 1px solid #dfe2e5;
        padding: 6px 13px;
    }
    th { background: rgba(27, 31, 35, 0.04); }
    img { max-width: 100%; }
    a { color: #0366d6; text-decoration: none; }
    a:hover { text-decoration: underline; }
    hr {
        border: none;
        border-top: 1px solid #e1e4e8;
        margin: 1.4em 0;
    }
    @media (prefers-color-scheme: dark) {
        body { color: #d4d4d4; background: #1e1e1e; }
        h1, h2 { border-bottom-color: #3c3c3c; }
        code { background: rgba(255, 255, 255, 0.1); }
        pre { background: rgba(255, 255, 255, 0.06); }
        blockquote { color: #8b949e; border-left-color: #3c3c3c; }
        th, td { border-color: #3c3c3c; }
        th { background: rgba(255, 255, 255, 0.06); }
        a { color: #58a6ff; }
        hr { border-top-color: #3c3c3c; }
    }
    """

    // MARK: - Coordinator

    /// 防抖调度:编辑停止 ~250ms 后才重新渲染,避免每次按键都整页刷新。
    /// 关键约束:Markdown → HTML 的组装绝不放主线程;只有
    /// `loadHTMLString` 回主线程调用。
    final class Coordinator: NSObject {
        var lastRenderedContent: String?
        private var pendingWork: DispatchWorkItem?
        /// 渲染代数:同高亮调度,期间有新输入/关闭预览时旧结果作废
        private var renderGeneration: UInt = 0
        /// 预览尺寸观察:分栏拖动改变行宽 → 内容高度变化,刷新换算基准
        private var boundsObservation: NSKeyValueObservation?
        /// 页面加载期间置位:渲染引起的 scroll 复位(0)不得反向回传编辑区
        private var isLoading = false
        private weak var sync: PreviewScrollSync?

        deinit {
            pendingWork?.cancel()
            boundsObservation?.invalidate()
        }

        /// 滚动联动接线:编辑侧经 SyntaxTextView.onDidScroll 上报,
        /// 预览侧经 messageHandlers 桥回传;此处登记 webView 引用与
        /// 尺寸观察(用于刷新内容高度换算基准)
        func bindScrollSync(_ sync: PreviewScrollSync, webView: WKWebView) {
            self.sync = sync
            sync.webView = webView
            boundsObservation?.invalidate()
            boundsObservation = webView.observe(\.bounds, options: [.new]) { [weak self] webView, _ in
                self?.refreshWebContentHeight(webView)
            }
        }

        /// 经 JS 查询预览文档总高并写入 sync(比例换算基准);
        /// completion 在结果落地后回调(主线程)
        private func refreshWebContentHeight(_ webView: WKWebView,
                                             completion: (() -> Void)? = nil) {
            let js = "Math.max(document.body ? document.body.scrollHeight : 0,"
                + " document.documentElement ? document.documentElement.scrollHeight : 0)"
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let height = result as? Double else { return }
                self?.sync?.webContentHeight = CGFloat(height)
                completion?()
            }
        }

        func scheduleRender(webView: WKWebView,
                            kind: MoteDocument.PreviewKind,
                            content: String,
                            baseURL: URL?) {
            pendingWork?.cancel()
            renderGeneration &+= 1
            let generation = renderGeneration

            let work = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }

                // 超过实时预览阈值的 Markdown:不跑渲染器,常量耗时的说明页
                if kind == .markdown, content.utf8.count > PreviewPanelView.liveMarkdownRenderLimit {
                    let html = PreviewPanelView.largeMarkdownNoticeHTML(sourceBytes: content.utf8.count)
                    DispatchQueue.main.async { [weak self, weak webView] in
                        guard let self, self.renderGeneration == generation, let webView else { return }
                        self.isLoading = true
                        webView.loadHTMLString(html, baseURL: baseURL)
                    }
                    return
                }

                // Markdown → HTML 是纯计算,放到后台;完成回主线程核对代数再加载
                DispatchQueue.global(qos: .userInitiated).async { [weak self, weak webView] in
                    guard let self, self.renderGeneration == generation else { return }
                    let html = PreviewPanelView.makeHTML(kind: kind, content: content)
                    DispatchQueue.main.async { [weak self, weak webView] in
                        guard let self, self.renderGeneration == generation, let webView else { return }
                        self.isLoading = true
                        webView.loadHTMLString(html, baseURL: baseURL)
                    }
                }
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

// MARK: - 页面加载完成

extension PreviewPanelView.Coordinator: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        // 注入滚动上报桥。页面 JS 仍被 `allowsContentJavaScript = false` 禁用,
        // 但原生 evaluateJavaScript 求值与 messageHandlers 通道不受影响(已实测验证)
        let installBridgeJS = """
        window.addEventListener('scroll', function(){
            window.webkit.messageHandlers.moteScroll.postMessage(window.scrollY);
        });
        'bridge-installed';
        """
        webView.evaluateJavaScript(installBridgeJS)
        refreshWebContentHeight(webView) { [weak self] in
            // 渲染完成后按编辑区当前位置同步一次,避免边输入边刷新时预览回跳顶部
            self?.sync?.editorDidScroll()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }
}

// MARK: - 滚动事件回传(page JS 禁用,经 messageHandlers 桥接收)

extension PreviewPanelView.Coordinator: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "moteScroll", let offsetY = message.body as? Double else { return }
        // 加载期间的 scroll 复位(0)不得回传,否则会把编辑区拽回顶部
        guard !isLoading else { return }
        sync?.previewDidScroll(offsetY: CGFloat(offsetY))
    }
}

// MARK: - 滚动联动

/// 编辑区 ↔ 预览双向滚动联动(比例映射 + 防回环窗口)。
///
/// macOS WKWebView 无原生 scrollView 可供 KVO,滚动控制与事件均走
/// evaluateJavaScript + messageHandlers 桥(页面 JS 禁用不影响,实测验证)。
/// 编辑侧事件来自 SyntaxTextView 的 contentView boundsDidChange。
/// 一侧编程滚动引发的另一侧滚动事件在 suppress 窗口内忽略,
/// 避免"滚 A → 滚 B → 又滚 A"的反馈震荡。
final class PreviewScrollSync {

    /// 编程滚动抑制窗口(秒)。滚动事件异步派发,0.25s 足以截断回环;
    /// 只影响"一侧滚动后立刻换滚另一侧"的极短过渡
    private static let suppressWindow: TimeInterval = 0.25

    /// 编辑区(由 SyntaxEditorRepresentable 注入)
    weak var textView: InnerTextView?
    /// 预览(由 PreviewPanelView.makeNSView 注入)
    weak var webView: WKWebView?

    /// 仅实时预览启用时联动:>256KB 暂停预览、SVG/HTML 原始渲染时无意义
    var isEnabled = false

    /// 预览文档内容高度(pt),渲染完成与分栏尺寸变化时经 JS 刷新。
    /// 用于"编辑滚动比例 → 预览目标 Y"的换算
    var webContentHeight: CGFloat = 0

    private var suppressPreviewUntil = Date.distantPast
    private var suppressEditorUntil = Date.distantPast

    // MARK: 编辑区 → 预览

    func editorDidScroll() {
        guard isEnabled, let textView, let webView,
              let editorScroll = textView.enclosingScrollView else { return }
        // 本次滚动由预览回传编程触发 → 不再回传
        guard Date() >= suppressEditorUntil else { return }
        guard let ratio = Self.scrollRatio(
            contentHeight: editorScroll.documentView?.bounds.height ?? 0,
            visibleHeight: editorScroll.contentView.bounds.height,
            offsetY: editorScroll.documentVisibleRect.origin.y) else { return }
        let maxOffset = max(webContentHeight - webView.bounds.height, 0)
        guard maxOffset > 0 else { return }
        suppressPreviewUntil = Date().addingTimeInterval(Self.suppressWindow)
        webView.evaluateJavaScript("window.scrollTo(0, \(ratio * maxOffset))")
    }

    // MARK: 预览 → 编辑区

    func previewDidScroll(offsetY: CGFloat) {
        guard isEnabled, let textView, let webView,
              let editorScroll = textView.enclosingScrollView else { return }
        guard Date() >= suppressPreviewUntil else { return }
        guard let ratio = Self.scrollRatio(
            contentHeight: webContentHeight,
            visibleHeight: webView.bounds.height,
            offsetY: offsetY) else { return }
        let maxOffset = max((editorScroll.documentView?.bounds.height ?? 0)
                            - editorScroll.contentView.bounds.height, 0)
        guard maxOffset > 0 else { return }
        suppressEditorUntil = Date().addingTimeInterval(Self.suppressWindow)
        editorScroll.contentView.scroll(to: NSPoint(x: 0, y: ratio * maxOffset))
    }

    /// 滚动比例 [0,1];内容不满一屏时返回 nil(不联动)
    private static func scrollRatio(contentHeight: CGFloat,
                                    visibleHeight: CGFloat,
                                    offsetY: CGFloat) -> CGFloat? {
        let maxOffset = max(contentHeight - visibleHeight, 0)
        guard maxOffset > 0 else { return nil }
        return min(max(offsetY / maxOffset, 0), 1)
    }
}


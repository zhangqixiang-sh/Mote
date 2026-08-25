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

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 静态预览不需要 JS,关掉以省内存、杜絕脚本注入面
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground") // 透明底,加载前不闪白
        render(into: webView)
        context.coordinator.lastRenderedContent = content
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard content != context.coordinator.lastRenderedContent else { return }
        context.coordinator.lastRenderedContent = content
        context.coordinator.scheduleRender { [weak webView] in
            guard let webView = webView else { return }
            render(into: webView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - 渲染

    private func render(into webView: WKWebView) {
        let html: String
        switch kind {
        case .markdown:
            let body = MarkdownRenderer.render(content)
            html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(Self.markdownStylesheet)</style>
            </head>
            <body>\(body)</body>
            </html>
            """
        case .webDocument:
            // SVG / HTML 原样渲染:保留文件自身结构与样式
            html = content
        }
        // baseURL 指向文档所在目录,使相对路径资源可加载
        webView.loadHTMLString(html, baseURL: fileURL?.deletingLastPathComponent())
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

    /// 防抖调度:编辑停止 ~250ms 后才重新渲染,避免每次按键都整页刷新
    final class Coordinator {
        var lastRenderedContent: String?
        private var pendingWork: DispatchWorkItem?

        func scheduleRender(_ render: @escaping () -> Void) {
            pendingWork?.cancel()
            let work = DispatchWorkItem(block: render)
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

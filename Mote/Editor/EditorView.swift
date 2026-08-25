import SwiftUI

/// 编辑器主视图
///
/// 架构约定:编辑区 100% 原生 TextKit(Sourceful 的 SyntaxTextView
/// 底层即 NSTextView + NSTextStorage),SwiftUI 仅作承载层,
/// 并通过 `colorScheme` 环境驱动深浅色主题切换。
///
/// M3/M4:可预览文档(Markdown / SVG / HTML)右侧分栏预览——只读
/// WKWebView,懒加载、按需创建(仅可预览文档且开关打开时存在)、
/// 关闭即释放,边输入边经 ~250ms 防抖刷新;预览开关在标题栏 toolbar。
struct EditorView: View {

    let document: MoteDocument

    @Environment(\.colorScheme) private var colorScheme

    /// 预览开关(仅可预览文档可见;关闭后 WebView 即从层级移除并释放)
    @State private var showsPreview = true

    /// 供预览渲染的文本快照:由编辑回调驱动,防抖逻辑在预览视图内部
    @State private var previewContent: String

    init(document: MoteDocument) {
        self.document = document
        _previewContent = State(initialValue: document.text)
    }

    var body: some View {
        let editor = SyntaxEditorRepresentable(
            document: document,
            themeStyle: colorScheme == .dark ? .dark : .light,
            onTextChange: { previewContent = $0 }
        )

        Group {
            if document.isPreviewable, let kind = document.previewKind, showsPreview {
                HSplitView {
                    editor.layoutPriority(1)
                    PreviewPanelView(kind: kind, content: previewContent, fileURL: document.fileURL)
                        .frame(minWidth: 320)
                }
            } else {
                editor
            }
        }
        .toolbar {
            if document.isPreviewable {
                ToolbarItem(placement: .automatic) {
                    SwiftUI.Button {
                        showsPreview.toggle()
                    } label: {
                        SwiftUI.Image(systemName: "sidebar.right")
                            .foregroundStyle(showsPreview ? SwiftUI.Color.accentColor : SwiftUI.Color.secondary)
                    }
                    .help(showsPreview ? "隐藏预览" : "显示预览")
                }
            }
        }
    }
}

/// Sourceful SyntaxTextView 的 SwiftUI 桥接
struct SyntaxEditorRepresentable: NSViewRepresentable {

    let document: MoteDocument
    let themeStyle: MoteThemeStyle
    /// 编辑内容变化回调(驱动预览刷新)
    var onTextChange: ((String) -> Void)?

    func makeNSView(context: Context) -> SyntaxTextView {
        let view = SyntaxTextView(frame: .zero)
        view.text = document.text
        view.delegate = context.coordinator
        view.theme = MoteThemeFactory.theme(for: themeStyle)
        context.coordinator.currentThemeStyle = themeStyle
        return view
    }

    func updateNSView(_ view: SyntaxTextView, context: Context) {
        // 回调引用随 SwiftUI 重建更新,避免闭包捕获过期状态
        context.coordinator.onTextChange = onTextChange
        // 仅在系统外观切换时更换主题,避免每次 SwiftUI 刷新都重绘
        guard context.coordinator.currentThemeStyle != themeStyle else { return }
        context.coordinator.currentThemeStyle = themeStyle
        view.theme = MoteThemeFactory.theme(for: themeStyle)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, onTextChange: onTextChange)
    }

    // MARK: - Coordinator

    /// 桥接 Sourceful 委托:按文档类型提供 Lexer,编辑时回写文档内容
    final class Coordinator: NSObject, SyntaxTextViewDelegate {

        private let document: MoteDocument
        var currentThemeStyle: MoteThemeStyle?
        var onTextChange: ((String) -> Void)?

        init(document: MoteDocument, onTextChange: ((String) -> Void)?) {
            self.document = document
            self.onTextChange = onTextChange
        }

        func lexerForSource(_ source: String) -> Lexer {
            document.lexer
        }

        func didChangeText(_ syntaxTextView: SyntaxTextView) {
            document.text = syntaxTextView.text
            document.updateChangeCount(.changeDone)
            onTextChange?(syntaxTextView.text)
        }
    }
}

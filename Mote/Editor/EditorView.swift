import SwiftUI

/// 编辑器主视图
///
/// 架构约定:编辑区 100% 原生 TextKit(Sourceful 的 SyntaxTextView
/// 底层即 NSTextView + NSTextStorage),SwiftUI 仅作承载层,
/// 并通过 `colorScheme` 环境驱动深浅色主题切换。
struct EditorView: View {

    let document: MoteDocument

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SyntaxEditorRepresentable(
            document: document,
            themeStyle: colorScheme == .dark ? .dark : .light
        )
    }
}

/// Sourceful SyntaxTextView 的 SwiftUI 桥接
struct SyntaxEditorRepresentable: NSViewRepresentable {

    let document: MoteDocument
    let themeStyle: MoteThemeStyle

    func makeNSView(context: Context) -> SyntaxTextView {
        let view = SyntaxTextView(frame: .zero)
        view.text = document.text
        view.delegate = context.coordinator
        view.theme = MoteThemeFactory.theme(for: themeStyle)
        context.coordinator.currentThemeStyle = themeStyle
        return view
    }

    func updateNSView(_ view: SyntaxTextView, context: Context) {
        // 仅在系统外观切换时更换主题,避免每次 SwiftUI 刷新都重绘
        guard context.coordinator.currentThemeStyle != themeStyle else { return }
        context.coordinator.currentThemeStyle = themeStyle
        view.theme = MoteThemeFactory.theme(for: themeStyle)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    // MARK: - Coordinator

    /// 桥接 Sourceful 委托:按文档类型提供 Lexer,编辑时回写文档内容
    final class Coordinator: NSObject, SyntaxTextViewDelegate {

        private let document: MoteDocument
        var currentThemeStyle: MoteThemeStyle?

        init(document: MoteDocument) {
            self.document = document
        }

        func lexerForSource(_ source: String) -> Lexer {
            document.lexer
        }

        func didChangeText(_ syntaxTextView: SyntaxTextView) {
            document.text = syntaxTextView.text
            document.updateChangeCount(.changeDone)
        }
    }
}

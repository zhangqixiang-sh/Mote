import SwiftUI

/// 编辑器主视图(SwiftUI 占位)
///
/// M1 骨架阶段仅展示占位内容;后续里程碑将替换为
/// 原生 NSTextView(编辑区)与懒加载预览面板(右侧)。
struct EditorView: View {

    let document: MoteDocument

    var body: some View {
        Text("Mote")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

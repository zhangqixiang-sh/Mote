# Vendored: Sourceful

来源: https://github.com/twostraws/Sourceful @ main (2023-09-18, MIT License, 见 LICENSE)

语法高亮引擎(SavannaKit 血统):NSTextView + NSTextStorage + 正则词法分析。
因构建环境 xcodebuild 的 SPM 沙箱限制(sandbox-exec: Operation not permitted),
改以源码形式直接编入 Mote 主 target,保持零外部依赖、可离线构建。

裁剪说明(不影响功能):
- 排除 `SwiftUI/SourceCodeTextEditor.swift` — SwiftUI 封装,与工程内的
  NSViewRepresentable 桥接重复
- 排除 `ASTVisualizer.swift` — 演示用调试视图

工程如需升级 Sourceful:克隆上游 → 按 `Util/Types.swift` 等结构覆盖本目录
→ 重新 `xcodegen generate`。

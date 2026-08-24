import AppKit

/// Mote 应用入口(AppKit 骨架,SwiftUI 内容渐进引入)
@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // M1 骨架阶段:不包含任何业务逻辑。
        // 语法高亮 / 预览 / 编码检测将在后续里程碑接入。
    }

    /// 关闭最后一个窗口后退出应用(文档型应用默认行为)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

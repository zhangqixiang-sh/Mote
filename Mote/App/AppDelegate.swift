import AppKit

/// Mote 应用入口
///
/// 显式声明 `main()` 以兼容 Xcode 26 的 debug-dylib 模式(仅靠 `@main`
/// 在 NSObject 子类上不会自动生成入口),并把 `applicationOpenUntitledFile`
/// 等行为挂到 `NSDocumentController` 默认实现上。
@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // NSDocumentController 自动接管打开/新建文档(基于 CFBundleDocumentTypes)。
        // 留空:didFinishLaunching 阶段不再做额外初始化。
    }

    /// 关闭最后一个文档窗口后退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

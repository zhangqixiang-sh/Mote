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
        buildMainMenu()
        // NSDocumentController 自动接管打开/新建文档(基于 CFBundleDocumentTypes)。
    }

    /// 关闭最后一个文档窗口后退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - 主菜单

    /// 构建标准主菜单。
    ///
    /// 背景:NSDocument 白送的撤销/重做、剪切/复制/粘贴、新建/打开/存储等
    /// 能力全部依赖菜单项把快捷键(keyEquivalent)路由到对应 action;此前工程
    /// 既没有 MainMenu.xib 也没有代码构建菜单,导致 ⌘Z 等快捷键无路由可走,
    /// 撤销看似"不存在"。补齐主菜单后:
    /// - 编辑菜单 Undo(⌘Z)/Redo(⇧⌘Z) 的 action 为 undo:/redo:,target 为 nil,
    ///   沿 first responder 链自动命中 NSTextView → document.undoManager
    /// - 文件/编辑/窗口菜单其余项由 NSDocumentController/NSDocument 自动启用
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // ── 应用菜单(第一个 submenu 由系统呈现为粗体应用名)──
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Mote")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 Mote", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 Mote", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Mote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // ── 文件菜单 ──
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "新建", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "打开…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "存储", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "存储为…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        fileMenu.addItem(withTitle: "还原到上次存储", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")

        // ── 编辑菜单(undo/redo 沿 responder chain 命中编辑区)──
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        let undoItem = NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "删除", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // ── 格式菜单(字体)──
        let formatItem = NSMenuItem()
        mainMenu.addItem(formatItem)
        let formatMenu = NSMenu(title: "格式")
        formatItem.submenu = formatMenu
        formatMenu.addItem(withTitle: "字体…", action: #selector(NSFontManager.orderFrontFontPanel(_:)), keyEquivalent: "t")

        // ── 窗口菜单 ──
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "前置全部窗口", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        // ── 帮助菜单 ──
        let helpItem = NSMenuItem()
        mainMenu.addItem(helpItem)
        let helpMenu = NSMenu(title: "帮助")
        helpItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "Mote 帮助", action: nil, keyEquivalent: "")

        NSApp.mainMenu = mainMenu
    }
}

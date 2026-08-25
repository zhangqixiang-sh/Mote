// 把 Mote 设为所有代码文件类型的默认打开方式
//
// 用法(需先构建并将 Mote.app 安装到 /Applications 或 ~/Applications):
//   1. xcodegen generate && xcodebuild -project Mote.xcodeproj -scheme Mote -configuration Debug -derivedDataPath build build
//   2. cp -R build/Build/Products/Debug/Mote.app ~/Applications/
//   3. /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Mote.app
//   4. swift scripts/set-default-handlers.swift
//
// 注意:
//   - 仅"已声明处理"的类型可设置默认,故列表需与 project.yml 的 LSItemContentTypes 保持同步
//   - markdown / plist 若被 Chrome/Qoder/Xcode 等通过"设为默认"机制保护,
//     本脚本无法覆盖,需在 Finder 中右键文件 → 打开方式 → 更改全部
import Foundation
import CoreServices

let bundleID = "com.mote.app" as NSString as CFString

let utis: [String] = [
    // 公共文本/源码类型
    "public.plain-text", "public.text", "public.source-code",
    "public.json", "public.swift-source",
    "public.c-source", "public.c-header",
    "public.c-plus-plus-source", "public.c-plus-plus-header",
    "public.objective-c-source", "public.objective-c-plus-plus-source",
    "public.python-script",
    "public.ruby-script", "public.php-script", "public.shell-script",
    "public.xml", "public.css", "public.log",
    "public.perl-script",
    // Mote 自定义 UTI
    "com.mote.yaml", "com.mote.markdown", "com.mote.toml",
    "com.mote.typescript", "com.mote.java", "com.mote.cpp",
    "com.mote.objc", "com.mote.csharp",
    "com.mote.go", "com.mote.rust", "com.mote.javascript",
    "com.mote.kotlin", "com.mote.scala", "com.mote.lua",
    "com.mote.ini", "com.mote.sql", "com.mote.plist",
    "com.mote.properties", "com.mote.dart", "com.mote.haskell",
    "com.mote.tex",
    // 系统/其他 app 声明的真实 UTI(已在 project.yml 的 LSItemContentTypes 中声明)
    "public.bash-script", "public.zsh-script", "public.toml",
    "public.yaml",
    "org.golang.go-script", "org.rust-lang.rust-script",
    "org.kotlinlang.source", "org.scala-lang.scala-source",
    "org.lua.lua-source", "org.haskell.haskell-script",
    "org.iso.sql", "org.tug.tex",
    "net.daringfireball.markdown",
    "com.netscape.javascript-source", "com.microsoft.typescript",
    "com.sun.java-source", "com.microsoft.c-sharp",
    "com.microsoft.ini", "com.apple.log", "com.apple.property-list",
    "dev.dart.dart-script", "com.coteditor.conf"
]

var failed = 0
var setOK = 0
for uti in utis {
    let status = LSSetDefaultRoleHandlerForContentType(uti as NSString as CFString, .editor, bundleID)
    if status == noErr { setOK += 1 }
    else { failed += 1; print("FAIL(\(status)) \(uti)") }
}
print("---- 成功 \(setOK) / 失败 \(failed) ----")
print("提示: markdown/plist 若被其他 app 保护,请在 Finder 手动 更改全部")

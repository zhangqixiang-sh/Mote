import Foundation

/// 语言检测:按文件扩展名选择词法分析器
///
/// 覆盖 24 种语言:
/// 内置 Lexer(5):Swift / Python / JavaScript / Java / OCaml
/// 自定义 Lexer(19):TypeScript / JSON / YAML / TOML / Markdown / HTML /
/// XML / CSS / C / C++ / Objective-C / C# / Go / Rust / Ruby / PHP /
/// Shell / SQL,外加纯文本兜底。
enum LanguageDetection {

    static let plain = PlainTextLexer()

    /// 支持的语言总数(用于验收口径:20~30 种)
    static var supportedLanguageCount: Int {
        // swift, python, javascript, typescript, java, ocaml, json, yaml,
        // toml, markdown, html, xml, css, c, c++, objective-c, c#, go,
        // rust, ruby, php, shell, sql = 23 种 + 纯文本兜底
        return 24
    }

    static func lexer(forFileExtension ext: String?) -> Lexer {
        switch ext?.lowercased() {
        // Sourceful 内置
        case "swift":
            return SwiftLexer()
        case "py", "python", "pyw":
            return Python3Lexer()
        case "js", "mjs", "cjs", "jsx":
            return JavaScriptLexer()
        case "java":
            return JavaLexer()
        case "ml", "mli":
            return OCamlLexer()

        // 自定义 Lexer
        case "ts", "tsx", "mts", "cts":
            return Lexers.typescript
        case "json":
            return Lexers.json
        case "yaml", "yml":
            return Lexers.yaml
        case "toml":
            return Lexers.toml
        case "md", "markdown", "mdown", "mkd":
            return Lexers.markdown
        case "html", "htm", "xhtml":
            return Lexers.html
        case "xml", "plist", "svg", "rss", "atom", "xib", "storyboard":
            return Lexers.html
        case "css":
            return Lexers.css
        case "c", "h":
            return Lexers.c
        case "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx":
            return Lexers.cpp
        case "m", "mm":
            return Lexers.objc
        case "cs", "csharp":
            return Lexers.csharp
        case "go":
            return Lexers.go
        case "rs":
            return Lexers.rust
        case "rb", "rbw", "ruby":
            return Lexers.ruby
        case "php":
            return Lexers.php
        case "sh", "bash", "zsh", "command":
            return Lexers.shell
        case "sql":
            return Lexers.sql

        default:
            return plain
        }
    }
}

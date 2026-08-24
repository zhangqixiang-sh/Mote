import Foundation

/// 各语言的词法规则定义
///
/// Sourceful 内置 5 种 Lexer(Swift / Python3 / JavaScript / Java / OCaml),
/// 其余语言基于 `GenericCodeLexer` 组合定义,合计覆盖 24 种语言。
/// TokenGenerator 工厂见 GenericCodeLexer.swift 中的 `token(_:options:tokenType:)`。
enum Lexers {

    // MARK: - JSON

    static let json = GenericCodeLexer(
        keywords: ["true", "false", "null"],
        extra: [
            // 键名(引号字符串后跟冒号)
            token(#""(?:[^"\\\n]|\\.)*"(?=\s*:)"#, tokenType: .identifier)
        ]
    )

    // MARK: - YAML

    static let yaml = GenericCodeLexer(
        keywords: ["true", "false", "null", "yes", "no", "on", "off"],
        lineComment: "#",
        extra: [
            // 键(行首缩进后的名字,后跟冒号)
            token(
                #"^[ \t]*[\w.\-/"']+(?=[ \t]*:)"#,
                options: [.anchorsMatchLines],
                tokenType: .identifier
            ),
            // 锚点与引用
            token(#"&[\w-]+|\*[\w-]+"#, tokenType: .keyword)
        ]
    )

    // MARK: - TOML

    static let toml = GenericCodeLexer(
        keywords: ["true", "false"],
        lineComment: "#",
        extra: [
            // [节] 标题
            token(#"^\s*\[[^\]\n]*\]"#, options: [.anchorsMatchLines], tokenType: .keyword),
            // 键名(后跟等号)
            token(#"^\s*[\w.\-"]+(?=\s*=)"#, options: [.anchorsMatchLines], tokenType: .identifier)
        ]
    )

    // MARK: - Markdown

    static let markdown = GenericCodeLexer(
        strings: false,
        numbers: false,
        extra: [
            // 围栏代码块(可跨行)
            token(#"```[\s\S]*?```"#, options: [.dotMatchesLineSeparators], tokenType: .string),
            // 行内代码
            token(#"`+[^`\n]*`+"#, tokenType: .string),
            // 标题
            token(#"^#{1,6}[ \t].*"#, options: [.anchorsMatchLines], tokenType: .keyword),
            // 引用块
            token(#"^>[ \t]?.*"#, options: [.anchorsMatchLines], tokenType: .comment),
            // 粗体 / 斜体
            token(#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, tokenType: .keyword),
            token(#"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#, tokenType: .identifier),
            // 链接 / 图片 [text](url) 与 [text][ref]
            token(#"!?\[[^\]\n*\]]*\]\([^)\n]*\)"#, tokenType: .identifier),
            // 列表标记
            token(#"^\s*(?:[-*+]|\d+\.)[ \t]"#, options: [.anchorsMatchLines], tokenType: .keyword)
        ]
    )

    // MARK: - HTML / XML

    static let html = GenericCodeLexer(
        strings: true,
        extra: [
            // 标签名(含开闭尖括号)
            token(#"</?[a-zA-Z][\w:.-]*"#, tokenType: .keyword),
            // 属性名(后跟等号)
            token(#"[a-zA-Z_:][\w:.-]*(?==)"#, tokenType: .identifier),
            // HTML 实体
            token(#"&[a-zA-Z]+;|&#\d+;"#, tokenType: .number),
            // HTML 注释放最后,覆盖注释内的其余标记
            token(#"<!--[\s\S]*?-->"#, options: [.dotMatchesLineSeparators], tokenType: .comment)
        ]
    )

    // MARK: - CSS

    static let css = GenericCodeLexer(
        blockComment: ("/*", "*/"),
        extra: [
            // @规则
            token(#"@[a-zA-Z-]+"#, tokenType: .keyword),
            // 属性名(后跟冒号)
            token(#"[-a-zA-Z]+(?=\s*:)"#, tokenType: .identifier),
            // 类 / ID 选择器
            token(#"\.[a-zA-Z][\w-]*|#[a-zA-Z][\w-]*"#, tokenType: .keyword),
            // 十六进制颜色
            token(#"#[0-9a-fA-F]{3,8}\b"#, tokenType: .number),
            // 数字 + 单位
            token(#"\b\d+(?:\.\d+)?(?:px|em|rem|vh|vw|pt|ch|%)?"#, tokenType: .number)
        ]
    )

    // MARK: - C / C++ / Objective-C / C#

    static let cKeywords = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if", "int",
        "long", "register", "return", "short", "signed", "sizeof", "static",
        "struct", "switch", "typedef", "union", "unsigned", "void", "volatile",
        "while", "include", "define", "ifdef", "ifndef", "endif", "pragma",
        "NULL", "true", "false"
    ]

    static let cppKeywords = cKeywords + [
        "bool", "class", "delete", "friend", "inline", "mutable", "namespace",
        "new", "operator", "override", "private", "protected", "public",
        "template", "this", "throw", "try", "catch", "typename", "using",
        "virtual", "nullptr", "constexpr", "noexcept", "final", "explicit",
        "nullptr", "std"
    ]

    static let objcKeywords = cKeywords + [
        "class", "interface", "implementation", "end", "property", "synthesize",
        "dynamic", "selector", "protocol", "autoreleasepool", "synchronized",
        "try", "catch", "finally", "throw", "id", "self", "super", "nil",
        "YES", "NO", "TRUE", "FALSE", "IBAction", "IBOutlet", "nonatomic",
        "atomic", "strong", "weak", "copy", "retain", "assign", "readonly"
    ]

    static let csharpKeywords = [
        "abstract", "as", "async", "await", "base", "bool", "break", "byte",
        "case", "catch", "char", "checked", "class", "const", "continue",
        "decimal", "default", "delegate", "do", "double", "else", "enum",
        "event", "explicit", "extern", "false", "finally", "fixed", "float",
        "for", "foreach", "get", "goto", "if", "implicit", "in", "int",
        "interface", "internal", "is", "lock", "long", "namespace", "new",
        "null", "object", "operator", "out", "override", "params", "private",
        "protected", "public", "readonly", "ref", "return", "sbyte", "sealed",
        "set", "short", "sizeof", "stackalloc", "static", "string", "struct",
        "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong",
        "unchecked", "unsafe", "ushort", "using", "value", "var", "virtual",
        "void", "volatile", "when", "where", "while", "yield"
    ]

    static let c = GenericCodeLexer(keywords: cKeywords, lineComment: "//", blockComment: ("/*", "*/"))
    static let cpp = GenericCodeLexer(keywords: cppKeywords, lineComment: "//", blockComment: ("/*", "*/"))
    static let objc = GenericCodeLexer(keywords: objcKeywords, lineComment: "//", blockComment: ("/*", "*/"))
    static let csharp = GenericCodeLexer(keywords: csharpKeywords, lineComment: "//", blockComment: ("/*", "*/"))

    // MARK: - Go

    static let go = GenericCodeLexer(
        keywords: [
            "break", "case", "chan", "const", "continue", "default", "defer",
            "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
            "interface", "map", "package", "range", "return", "select",
            "struct", "switch", "type", "var",
            "bool", "byte", "complex64", "complex128", "error", "float32",
            "float64", "int", "int8", "int16", "int32", "int64", "rune",
            "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
            "true", "false", "nil", "iota",
            "append", "cap", "close", "copy", "delete", "imag", "len", "make",
            "new", "panic", "print", "println", "real", "recover"
        ],
        lineComment: "//",
        blockComment: ("/*", "*/")
    )

    // MARK: - Rust

    static let rust = GenericCodeLexer(
        keywords: [
            "as", "async", "await", "break", "const", "continue", "crate",
            "dyn", "else", "enum", "extern", "false", "fn", "for", "if",
            "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
            "ref", "return", "self", "Self", "static", "struct", "super",
            "trait", "true", "type", "unsafe", "use", "where", "while",
            "abstract", "become", "box", "do", "final", "macro", "override",
            "priv", "typeof", "unsized", "virtual", "yield", "try",
            "u8", "u16", "u32", "u64", "u128", "usize", "i8", "i16", "i32",
            "i64", "i128", "isize", "f32", "f64", "bool", "char", "str",
            "String", "Vec", "Option", "Result", "Some", "None", "Ok", "Err"
        ],
        lineComment: "//",
        blockComment: ("/*", "*/")
    )

    // MARK: - Ruby

    static let ruby = GenericCodeLexer(
        keywords: [
            "def", "end", "class", "module", "if", "elsif", "else", "unless",
            "case", "when", "while", "until", "for", "do", "then", "begin",
            "rescue", "ensure", "raise", "return", "yield", "require",
            "require_relative", "include", "extend", "attr_accessor",
            "attr_reader", "attr_writer", "new", "self", "nil", "true",
            "false", "and", "or", "not", "lambda", "proc", "puts", "print",
            "p", "private", "protected", "public", "super", "alias", "defined?"
        ],
        lineComment: "#",
        extra: [
            // 符号 :symbol 与实例/全局变量
            token(#":[a-zA-Z_]\w*[?!]?"#, tokenType: .identifier),
            token(#"[@@$][a-zA-Z_]\w*"#, tokenType: .identifier)
        ]
    )

    // MARK: - PHP

    static let php = GenericCodeLexer(
        keywords: [
            "abstract", "and", "array", "as", "break", "callable", "case",
            "catch", "class", "clone", "const", "continue", "declare",
            "default", "do", "echo", "else", "elseif", "empty", "enddeclare",
            "endfor", "endforeach", "endif", "endswitch", "endwhile", "enum",
            "extends", "final", "finally", "fn", "for", "foreach", "function",
            "global", "goto", "if", "implements", "include", "include_once",
            "instanceof", "insteadof", "interface", "isset", "list", "match",
            "namespace", "new", "or", "print", "private", "protected", "public",
            "readonly", "require", "require_once", "return", "static", "switch",
            "throw", "trait", "try", "unset", "use", "var", "while", "xor",
            "yield", "true", "false", "null", "this"
        ],
        lineComment: "//",
        blockComment: ("/*", "*/"),
        extra: [
            // 变量 $name
            token(#"\$[a-zA-Z_]\w*"#, tokenType: .identifier),
            // 预定义常量
            token(#"__\w+__"#, tokenType: .keyword)
        ]
    )

    // MARK: - Shell

    static let shell = GenericCodeLexer(
        keywords: [
            "if", "then", "else", "elif", "fi", "for", "while", "until", "do",
            "done", "case", "esac", "function", "in", "select", "time",
            "export", "local", "readonly", "declare", "unset", "source",
            "return", "exit", "echo", "printf", "read", "cd", "set", "alias",
            "shift", "eval", "exec", "trap", "true", "false"
        ],
        lineComment: "#",
        extra: [
            // 变量 $VAR / ${VAR} / $1
            token(#"\$\{?\w+\}?"#, tokenType: .identifier),
            // 命令替换 $(...)
            token(#"\$\([^)\n]*\)"#, tokenType: .identifier)
        ]
    )

    // MARK: - SQL

    static let sqlKeywords = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "ADD", "COLUMN",
        "INDEX", "VIEW", "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "FULL",
        "CROSS", "ON", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "BETWEEN",
        "LIKE", "EXISTS", "DISTINCT", "GROUP", "BY", "ORDER", "HAVING",
        "LIMIT", "OFFSET", "UNION", "ALL", "PRIMARY", "KEY", "FOREIGN",
        "REFERENCES", "DEFAULT", "CHECK", "UNIQUE", "CASCADE", "COMMIT",
        "ROLLBACK", "TRANSACTION", "BEGIN", "CASE", "WHEN", "THEN", "ELSE",
        "END", "ASC", "DESC", "COUNT", "SUM", "AVG", "MIN", "MAX", "CONFLICT",
        "RETURNING", "WITH", "RECURSIVE", "VACUUM", "ANALYZE", "EXPLAIN"
    ]

    static let sql = GenericCodeLexer(
        keywords: sqlKeywords + sqlKeywords.map { $0.lowercased() },
        lineComment: "--",
        blockComment: ("/*", "*/")
    )

    // MARK: - TypeScript

    static let typescript = GenericCodeLexer(
        keywords: [
            "abstract", "any", "as", "async", "await", "boolean", "break",
            "case", "catch", "class", "const", "continue", "declare",
            "default", "delete", "do", "else", "enum", "export", "extends",
            "false", "finally", "for", "from", "function", "if", "implements",
            "import", "in", "instanceof", "interface", "let", "namespace",
            "never", "new", "null", "number", "of", "private", "protected",
            "public", "readonly", "return", "satisfies", "string", "super",
            "switch", "symbol", "this", "throw", "true", "try", "type",
            "typeof", "undefined", "unknown", "var", "void", "while", "yield",
            "console"
        ],
        lineComment: "//",
        blockComment: ("/*", "*/"),
        extra: [
            // 类型注解 :Type(不含空白)
            token(#"(?<=:)\s*[A-Z]\w*"#, tokenType: .identifier)
        ]
    )
}

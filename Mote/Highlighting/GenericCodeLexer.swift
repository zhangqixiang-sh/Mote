import Foundation

/// 模块级 TokenGenerator 工厂
///
/// Sourceful 的 `regexGenerator` 是 RegexLexer 的实例扩展方法,在
/// `Lexers` 枚举静态属性与 `GenericCodeLexer` 的 init 阶段均不可用
/// (self 未完成初始化),故提供等价的自由函数。
func token(
    _ pattern: String,
    options: NSRegularExpression.Options = [],
    tokenType: SourceCodeTokenType
) -> TokenGenerator? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        return nil
    }
    return .regex(RegexTokenGenerator(regularExpression: regex, tokenTransformer: {
        SimpleSourceCodeToken(type: tokenType, range: $0)
    }))
}

/// 通用正则词法分析器
///
/// 通过「关键词表 + 行/块注释标记 + 字符串规则」组合出一种语言的
/// 高亮规则,配合 `LanguageDetection` 覆盖 Sourceful 内置 Lexer 之外的
/// 常见语言。规则生效顺序与 Sourceful 内置 Lexer 一致:
/// 数字 → 关键词 → 注释 → 字符串(后应用者覆盖先应用者)。
final class GenericCodeLexer: SourceCodeRegexLexer {

    private let cached: [TokenGenerator]

    /// - Parameters:
    ///   - keywords: 关键词表(按词匹配,大小写敏感)
    ///   - lineComment: 行注释标记,如 "//"、"#"
    ///   - blockComment: 块注释 (开标记, 闭标记),如 ("/*", "*/")
    ///   - strings: 是否启用通用字符串规则(双引号/单引号/反引号,含转义)
    ///   - numbers: 是否启用通用数字规则(含十六进制/二进制/浮点/科学计数)
    ///   - extra: 追加规则(最后应用,优先级最高),如键名、标签、选择器等
    init(
        keywords: [String] = [],
        lineComment: String? = nil,
        blockComment: (String, String)? = nil,
        strings: Bool = true,
        numbers: Bool = true,
        extra: [TokenGenerator?] = []
    ) {
        var generators: [TokenGenerator?] = []

        if numbers {
            generators.append(token(
                #"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?)\b"#,
                tokenType: .number
            ))
        }

        if !keywords.isEmpty {
            generators.append(.keywords(KeywordTokenGenerator(
                keywords: keywords,
                tokenTransformer: { SimpleSourceCodeToken(type: .keyword, range: $0) }
            )))
        }

        if let marker = lineComment {
            let escaped = NSRegularExpression.escapedPattern(for: marker)
            generators.append(token("\(escaped).*", tokenType: .comment))
        }

        if let (open, close) = blockComment {
            let openEsc = NSRegularExpression.escapedPattern(for: open)
            let closeEsc = NSRegularExpression.escapedPattern(for: close)
            generators.append(token(
                "\(openEsc).*?\(closeEsc)",
                options: [.dotMatchesLineSeparators],
                tokenType: .comment
            ))
        }

        if strings {
            // 双引号 / 单引号(单行)
            generators.append(token(#""(?:[^"\\\n]|\\.)*""#, tokenType: .string))
            generators.append(token(#"'(?:[^'\\\n]|\\.)*'"#, tokenType: .string))
            // 反引号(可跨行)
            generators.append(token(
                #"`(?:[^`\\]|\\.)*`"#,
                options: [.dotMatchesLineSeparators],
                tokenType: .string
            ))
        }

        generators.append(contentsOf: extra)

        self.cached = generators.compactMap { $0 }
    }

    func generators(source: String) -> [TokenGenerator] {
        cached
    }
}

/// 无高亮词法分析器:纯文本 / 未知类型文件的兜底
final class PlainTextLexer: SourceCodeRegexLexer {
    func generators(source: String) -> [TokenGenerator] { [] }
}

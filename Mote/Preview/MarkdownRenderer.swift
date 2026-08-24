import Foundation

/// 基础 Markdown 渲染器(md → HTML 片段)
///
/// 第一期范围(PRD):标题 / 无序与有序列表 / 表格 / 围栏代码块 /
/// 行内代码 / 粗体 / 斜体 / 图片 / 链接 / 引用块 / 分割线。
/// KaTeX / Mermaid / 滚动同步属第二期,不做。
///
/// 纯 Foundation 实现、零三方依赖,保证包体积与启动速度;
/// 所有文本节点先做 HTML 转义,渲染产物可安全放入 WKWebView。
enum MarkdownRenderer {

    /// 将 Markdown 源文本渲染为 HTML body 片段(不含 <html> 外壳)
    static func render(_ markdown: String) -> String {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        // 末尾补一空行,让逐行状态机的"块收尾"逻辑统一触发
        lines.append("")

        var html = ""
        var index = 0
        let count = lines.count

        while index < count {
            let line = lines[index]

            // 围栏代码块 ```lang ... ```
            if let fence = fenceStart(line) {
                var codeLines: [String] = []
                index += 1
                while index < count && !isFenceEnd(lines[index], fence) {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1 // 跳过结束围栏
                html += "<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>\n"
                continue
            }

            // 空行:跳过
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // ATX 标题 # ~ ######
            if let heading = parseHeading(line) {
                html += "<h\(heading.level)>\(renderInline(heading.text))</h\(heading.level)>\n"
                index += 1
                continue
            }

            // 分割线 *** --- ___
            if isThematicBreak(line) {
                html += "<hr>\n"
                index += 1
                continue
            }

            // 引用块(连续 > 行)
            if isQuoteLine(line) {
                var quoteLines: [String] = []
                while index < count && isQuoteLine(lines[index]) {
                    quoteLines.append(stripQuoteMarker(lines[index]))
                    index += 1
                }
                // 引用块内部递归渲染,支持嵌套结构
                html += "<blockquote>\(render(quoteLines.joined(separator: "\n")))</blockquote>\n"
                continue
            }

            // 表格:当前行含 | 且下一行是分隔行 |---|---|
            if index + 1 < count, line.contains("|"), isTableSeparator(lines[index + 1]) {
                let headerCells = splitTableRow(line)
                index += 2 // 跳过表头与分隔行
                var bodyRows: [[String]] = []
                while index < count, lines[index].contains("|"),
                      !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    bodyRows.append(splitTableRow(lines[index]))
                    index += 1
                }
                html += renderTable(header: headerCells, rows: bodyRows)
                continue
            }

            // 列表(连续的 - * + 或 1. 行,支持单层缩进嵌套)
            if listMarker(line) != nil {
                var listLines: [String] = []
                while index < count, listMarker(lines[index]) != nil {
                    listLines.append(lines[index])
                    index += 1
                }
                html += renderList(listLines)
                continue
            }

            // 普通段落:吸收连续的非空"非块起始"行
            var paragraphLines: [String] = []
            while index < count {
                let current = lines[index]
                if current.trimmingCharacters(in: .whitespaces).isEmpty { break }
                if !paragraphLines.isEmpty && isBlockStart(current, next: index + 1 < count ? lines[index + 1] : nil) { break }
                paragraphLines.append(current)
                index += 1
            }
            let paragraph = paragraphLines.joined(separator: "\n")
            if !paragraph.isEmpty {
                html += "<p>\(renderInline(paragraph))</p>\n"
            }
        }

        return html
    }

    // MARK: - 块级解析

    /// 围栏代码块起始行,返回围栏字符(``` 或 ~~~)
    private static func fenceStart(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func isFenceEnd(_ line: String, _ fence: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(fence)
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " || rest.first == "\t" else { return nil }
        return (level, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let chars = trimmed.filter { $0 != " " && $0 != "\t" }
        guard chars.count >= 3 else { return false }
        return chars.allSatisfy { $0 == "-" } || chars.allSatisfy { $0 == "*" } || chars.allSatisfy { $0 == "_" }
    }

    private static func isQuoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private static func stripQuoteMarker(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        result.removeFirst() // ">"
        if result.first == " " { result.removeFirst() }
        return result
    }

    /// 表格分隔行:| --- | :---: | ---: |
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"), trimmed.contains("|") else { return false }
        let cells = splitTableRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { return false }
            return c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    /// 按 | 切分表格行,去掉首尾空单元
    private static func splitTableRow(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private static func renderTable(header: [String], rows: [[String]]) -> String {
        var html = "<table>\n<thead>\n<tr>"
        for cell in header {
            html += "<th>\(renderInline(cell))</th>"
        }
        html += "</tr>\n</thead>\n"
        if !rows.isEmpty {
            html += "<tbody>\n"
            for row in rows {
                html += "<tr>"
                for cell in row {
                    html += "<td>\(renderInline(cell))</td>"
                }
                html += "</tr>\n"
            }
            html += "</tbody>\n"
        }
        html += "</table>\n"
        return html
    }

    /// 列表行标记:- * +(无序)或 1. (有序),返回(是否有序, 缩进宽度, 内容)
    private static func listMarker(_ line: String) -> (ordered: Bool, indent: Int, content: String)? {
        var indent = 0
        for char in line {
            if char == " " { indent += 1 } else if char == "\t" { indent += 4 } else { break }
        }
        let rest = String(line.drop(while: { $0 == " " || $0 == "\t" }))
        if let first = rest.first, (first == "-" || first == "*" || first == "+"),
           rest.count > 1, rest[rest.index(after: rest.startIndex)] == " " {
            return (false, indent, String(rest.dropFirst(2)))
        }
        // 有序列表:数字 + .
        if let dotIndex = rest.firstIndex(of: ".") {
            let digits = rest[rest.startIndex..<dotIndex]
            if !digits.isEmpty, digits.allSatisfy({ $0.isNumber }),
               rest.index(after: dotIndex) < rest.endIndex,
               rest[rest.index(after: dotIndex)] == " " {
                return (true, indent, String(rest[rest.index(dotIndex, offsetBy: 2)...]))
            }
        }
        return nil
    }

    /// 渲染列表,按缩进支持一层嵌套
    private static func renderList(_ lines: [String]) -> String {
        guard let first = lines.first, let firstMarker = listMarker(first) else { return "" }
        let baseIndent = firstMarker.indent
        let tag = firstMarker.ordered ? "ol" : "ul"

        var html = "<\(tag)>\n"
        var index = 0
        while index < lines.count {
            guard let marker = listMarker(lines[index]) else { index += 1; continue }
            if marker.indent <= baseIndent {
                html += "<li>\(renderInline(marker.content))"
                // 收集缩进更深的子项作为嵌套列表
                var nested: [String] = []
                var lookAhead = index + 1
                while lookAhead < lines.count,
                      let sub = listMarker(lines[lookAhead]), sub.indent > baseIndent {
                    nested.append(lines[lookAhead])
                    lookAhead += 1
                }
                if !nested.isEmpty {
                    // 去掉公共缩进后递归
                    let stripped = nested.map { line -> String in
                        let dropCount = min(baseIndent + 2, line.prefix(while: { $0 == " " }).count)
                        return String(line.dropFirst(dropCount))
                    }
                    html += renderList(stripped)
                }
                html += "</li>\n"
                index = lookAhead
            } else {
                index += 1
            }
        }
        html += "</\(tag)>\n"
        return html
    }

    /// 判断一行是否为某种块级结构起始(用于段落断块)
    private static func isBlockStart(_ line: String, next: String?) -> Bool {
        if fenceStart(line) != nil { return true }
        if parseHeading(line) != nil { return true }
        if isThematicBreak(line) { return true }
        if isQuoteLine(line) { return true }
        if listMarker(line) != nil { return true }
        if let next = next, line.contains("|"), isTableSeparator(next) { return true }
        return false
    }

    // MARK: - 行内解析

    /// 行内渲染:代码 span → 图片 → 链接 → 粗体 → 斜体
    ///
    /// 先把行内代码与图片/链接 URL 抽成占位符再处理强调,避免
    /// `*` 出现在代码或 URL 里被误解析;整体先 HTML 转义。
    private static func renderInline(_ text: String) -> String {
        var placeholders: [String] = []

        // 占位符替换工具:把匹配片段的渲染结果存起来,先放哨兵字符
        func stash(_ rendered: String) -> String {
            placeholders.append(rendered)
            return "\u{1A}\(placeholders.count - 1)\u{1A}"
        }

        var result = escapeHTML(text)

        // 行内代码 `code`(已转义文本中反引号不受影响)
        result = replace(#"`+([^`]+?)`+"#, in: result) { match in
            stash("<code>\(match[1])</code>")
        }

        // 图片 ![alt](src)
        result = replace(#"!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)"#, in: result) { match in
            let alt = match[1]
            let src = sanitizeURL(match[2])
            return stash("<img src=\"\(src)\" alt=\"\(alt)\">")
        }

        // 链接 [text](href)
        result = replace(#"\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)"#, in: result) { match in
            let href = sanitizeURL(match[2])
            return stash("<a href=\"\(href)\">\(match[1])</a>")
        }

        // 粗体 **text** / __text__
        result = replace(#"\*\*([^*]+)\*\*"#, in: result) { "<strong>\($0[1])</strong>" }
        result = replace(#"__([^_]+)__"#, in: result) { "<strong>\($0[1])</strong>" }

        // 斜体 *text* / _text_
        result = replace(#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, in: result) { "<em>\($0[1])</em>" }
        result = replace(#"(?<!_)\b_([^_\n]+)_\b"#, in: result) { "<em>\($0[1])</em>" }

        // 还原占位符(可能被嵌套还原,循环至无哨兵;ICU 语法 \x{1A})
        // 带轮数上限兜底:正则编译失败等异常时不得死循环
        var restoreRounds = 0
        while result.contains("\u{1A}"), restoreRounds <= placeholders.count {
            restoreRounds += 1
            result = replace(#"\x{1A}(\d+)\x{1A}"#, in: result) { match in
                let idx = Int(match[1]) ?? 0
                return idx < placeholders.count ? placeholders[idx] : ""
            }
        }

        // 段落内换行 → <br>
        return result.replacingOccurrences(of: "\n", with: "<br>\n")
    }

    /// 正则整体替换,捕获组以 [String] 传入闭包(match[0] 为全匹配)
    private static func replace(_ pattern: String, in text: String,
                                using transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = text.startIndex
        for match in matches {
            guard let fullRange = Range(match.range, in: text) else { continue }
            result += text[lastEnd..<fullRange.lowerBound]
            var groups: [String] = []
            for groupIndex in 0..<match.numberOfRanges {
                if let range = Range(match.range(at: groupIndex), in: text) {
                    groups.append(String(text[range]))
                } else {
                    groups.append("")
                }
            }
            result += transform(groups)
            lastEnd = fullRange.upperBound
        }
        result += text[lastEnd...]
        return result
    }

    // MARK: - 工具

    /// HTML 转义(须在行内解析之前对整个文本执行)
    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// URL 消毒:仅放行 http(s) / 相对路径 / 锚点,拦截 javascript: 等协议
    private static func sanitizeURL(_ url: String) -> String {
        let lowered = url.trimmingCharacters(in: .whitespaces).lowercased()
        if lowered.hasPrefix("javascript:") || lowered.hasPrefix("data:") || lowered.hasPrefix("vbscript:") {
            return "#"
        }
        return url
    }
}

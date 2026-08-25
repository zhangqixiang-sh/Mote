import Foundation

/// 编码自动检测(参考 CotEditor 的嗅探思路)
///
/// 第一期范围(PRD):UTF-8 / UTF-16(LE/BE,含 BOM 与无 BOM 启发式)/
/// GBK(经 GB18030 兼容)/GB18030。
///
/// 检测顺序:
/// 1. BOM 嗅探:EF BB BF(UTF-8)/ FF FE(UTF-16LE)/ FE FF(UTF-16BE)
/// 2. UTF-16 无 BOM 启发式:奇偶位空字节分布(排除 UTF-32 与纯文本)
/// 3. UTF-8 严格解码(非法序列即失败)
/// 4. GB18030 兜底(完整覆盖 Unicode,几乎总能成功)
///
/// 解码结果保留 `encoding` 与 `hasBOM`,供保存时按原编码写回。
enum TextEncodingDetector {

    struct Result {
        let text: String
        let encoding: String.Encoding
        let hasBOM: Bool
    }

    /// GB18030 的 String.Encoding(CoreFoundation 提供,系统内置)
    static var gb18030: String.Encoding {
        let cfEnc = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
    }

    static func decode(_ data: Data) throws -> Result {
        guard !data.isEmpty else {
            return Result(text: "", encoding: .utf8, hasBOM: false)
        }

        // 1. BOM 嗅探
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let payload = data.dropFirst(3)
            guard let text = String(data: payload, encoding: .utf8) else {
                throw encodingError("UTF-8 (BOM)")
            }
            return Result(text: text, encoding: .utf8, hasBOM: true)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            let payload = data.dropFirst(2)
            guard let text = String(data: payload, encoding: .utf16LittleEndian) else {
                throw encodingError("UTF-16LE (BOM)")
            }
            return Result(text: text, encoding: .utf16LittleEndian, hasBOM: true)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            let payload = data.dropFirst(2)
            guard let text = String(data: payload, encoding: .utf16BigEndian) else {
                throw encodingError("UTF-16BE (BOM)")
            }
            return Result(text: text, encoding: .utf16BigEndian, hasBOM: true)
        }

        // 2. UTF-16 无 BOM 启发式:偶数位 / 奇数位空字节占比
        if let utf16 = sniffUTF16WithoutBOM(data) {
            return utf16
        }

        // 3. UTF-8 严格解码
        if let text = String(data: data, encoding: .utf8) {
            return Result(text: text, encoding: .utf8, hasBOM: false)
        }

        // 4. GB18030 兜底(GBK 为其子集,中文遗留编码文件落到这里)
        if let text = String(data: data, encoding: gb18030) {
            return Result(text: text, encoding: gb18030, hasBOM: false)
        }

        throw encodingError("未知编码")
    }

    // MARK: - UTF-16 无 BOM 启发式

    /// 通过空字节分布判断无 BOM 的 UTF-16 LE/BE:
    /// ASCII 文本在 UTF-16 中每个字符高低位成对,一半字节为 0x00。
    private static func sniffUTF16WithoutBOM(_ data: Data) -> Result? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes.count.isMultiple(of: 2) else { return nil }

        // 只采样前 512 字节以加速(对超大文件足够了)
        let sample = bytes.prefix(512)
        let evenZeros = sample.enumerated().filter { $0.offset % 2 == 0 && $0.element == 0 }.count
        let oddZeros = sample.enumerated().filter { $0.offset % 2 == 1 && $0.element == 0 }.count
        let evenCount = (sample.count + 1) / 2
        let oddCount = sample.count / 2

        // 空字节占比阈值:某种排列下过半为空字节 → 判为 UTF-16
        if oddCount > 0, Double(oddZeros) / Double(oddCount) > 0.5, evenZeros < evenCount / 4 {
            // 奇数位(第二个字节)多为 0 → little-endian
            if let text = String(data: data, encoding: .utf16LittleEndian) {
                return Result(text: text, encoding: .utf16LittleEndian, hasBOM: false)
            }
        }
        if evenCount > 0, Double(evenZeros) / Double(evenCount) > 0.5, oddZeros < oddCount / 4 {
            // 偶数位(第一个字节)多为 0 → big-endian
            if let text = String(data: data, encoding: .utf16BigEndian) {
                return Result(text: text, encoding: .utf16BigEndian, hasBOM: false)
            }
        }
        return nil
    }

    // MARK: - 写回

    /// 按检测结果编码写回,保留 BOM
    static func encode(_ text: String, encoding: String.Encoding, hasBOM: Bool) -> Data {
        var data: Data
        switch encoding {
        case .utf16LittleEndian:
            data = text.data(using: .utf16LittleEndian) ?? Data()
            if hasBOM { data.insert(contentsOf: [0xFF, 0xFE], at: 0) }
        case .utf16BigEndian:
            data = text.data(using: .utf16BigEndian) ?? Data()
            if hasBOM { data.insert(contentsOf: [0xFE, 0xFF], at: 0) }
        case .utf8:
            data = text.data(using: .utf8) ?? Data()
            if hasBOM { data.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0) }
        default:
            data = text.data(using: encoding) ?? Data(text.utf8)
        }
        return data
    }

    private static func encodingError(_ name: String) -> NSError {
        NSError(
            domain: "MoteDocumentError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "无法以 \(name) 解码文件内容"]
        )
    }
}

//
//  SyntaxTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 23/01/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public protocol SyntaxTextViewDelegate: AnyObject {

    func didChangeText(_ syntaxTextView: SyntaxTextView)

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange)

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView)

    func lexerForSource(_ source: String) -> Lexer

}

// Provide default empty implementations of methods that are optional.
public extension SyntaxTextViewDelegate {
    func didChangeText(_ syntaxTextView: SyntaxTextView) { }

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) { }

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) { }
}

struct ThemeInfo {

    let theme: SyntaxColorTheme

    /// Width of a space character in the theme's font.
    /// Useful for calculating tab indent size.
    let spaceWidth: CGFloat

}

@IBDesignable
open class SyntaxTextView: _View {

    var previousSelectedRange: NSRange?

    private var textViewSelectedRangeObserver: NSKeyValueObservation?

    let textView: InnerTextView

    /// 编辑区滚动回调(预览联动用):contentView 的 boundsDidChange 通知
    /// 每次滚动触发,与 gutter 重绘共用同一事件源
    var onDidScroll: (() -> Void)?

    public var contentTextView: TextView {
        return textView
    }

    public weak var delegate: SyntaxTextViewDelegate? {
        didSet {
            refreshColors()
        }
    }

    var ignoreSelectionChange = false

    #if os(macOS)

    let wrapperView = TextViewWrapperView()

    #endif

    #if os(iOS)

    public var contentInset: UIEdgeInsets = .zero {
        didSet {
            textView.contentInset = contentInset
            textView.scrollIndicatorInsets = contentInset
        }
    }

    open override var tintColor: UIColor! {
        didSet {

        }
    }

    #else

    public var tintColor: NSColor! {
        set {
            textView.tintColor = newValue
        }
        get {
            return textView.tintColor
        }
    }

    #endif
    
    public override init(frame: CGRect) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(coder: aDecoder)
        setup()
    }

    private static func createInnerTextView() -> InnerTextView {
        let textStorage = NSTextStorage()
        let layoutManager = SyntaxTextViewLayoutManager()
        #if os(macOS)
        let containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        #endif

        #if os(iOS)
        let containerSize = CGSize(width: 0, height: 0)
        #endif

        let textContainer = NSTextContainer(size: containerSize)
        
        textContainer.widthTracksTextView = true

        #if os(iOS)
        textContainer.heightTracksTextView = true
        #endif
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        return InnerTextView(frame: .zero, textContainer: textContainer)
    }

    #if os(macOS)

    public let scrollView = NSScrollView()

    #endif

    private func setup() {

        textView.gutterWidth = 20

        #if os(iOS)

        textView.translatesAutoresizingMaskIntoConstraints = false

        #endif

        #if os(macOS)

        wrapperView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        scrollView.contentView.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)

        addSubview(wrapperView)


        scrollView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        wrapperView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        wrapperView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        wrapperView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        wrapperView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true


        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerKnobStyle = .light

        scrollView.documentView = textView

        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self, selector: #selector(didScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        textView.minSize = NSSize(width: 0.0, height: self.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true

        textView.textContainer?.containerSize = NSSize(width: self.bounds.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        //			textView.layerContentsRedrawPolicy = .beforeViewResize

        wrapperView.textView = textView

        #else

        self.addSubview(textView)
        textView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        textView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        self.contentMode = .redraw
        textView.contentMode = .topLeft

        textViewSelectedRangeObserver = contentTextView.observe(\UITextView.selectedTextRange) { [weak self] (textView, value) in

            if let `self` = self {
                self.delegate?.didChangeSelectedRange(self, selectedRange: self.contentTextView.selectedRange)
            }

        }

        #endif

        textView.innerDelegate = self
        textView.delegate = self

        textView.text = ""

        #if os(iOS)

        textView.autocapitalizationType = .none
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no

        if #available(iOS 11.0, *) {
            textView.smartQuotesType = .no
            textView.smartInsertDeleteType = .no
        }

        self.clipsToBounds = true

        #endif

    }

    #if os(macOS)

    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

    }

    @objc func didScroll(_ notification: Notification) {

        wrapperView.setNeedsDisplay(wrapperView.bounds)

        onDidScroll?()
    }

    #endif

    // MARK: -

    #if os(iOS)

    open override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }
    override open var isFirstResponder: Bool {
        return textView.isFirstResponder
    }

    #endif

    @IBInspectable
    public var text: String {
        get {
            #if os(macOS)
            return textView.string
            #else
            return textView.text ?? ""
            #endif
        }
        set {
            #if os(macOS)
            textView.layer?.isOpaque = true
            textView.string = newValue
            refreshColors()
            #else
            // If the user sets this property as soon as they create the view, we get a strange UIKit bug where the text often misses a final line in some Dynamic Type configurations. The text isn't actually missing: if you background the app then foreground it the text reappears just fine, so there's some sort of drawing sync problem. A simple fix for this is to give UIKit a tiny bit of time to create all its data before we trigger the update, so we push the updating work to the runloop.
            DispatchQueue.main.async {
                self.textView.text = newValue
                self.textView.setNeedsDisplay()
                self.refreshColors()
            }
            #endif

        }
    }

    // MARK: -

    public func insertText(_ text: String) {
        if shouldChangeText(insertingText: text) {
            #if os(macOS)
            contentTextView.insertText(text, replacementRange: contentTextView.selectedRange())
            #else
            contentTextView.insertText(text)
            #endif
        }
    }

    #if os(iOS)

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.textView.setNeedsDisplay()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        self.textView.invalidateCachedParagraphs()
        self.textView.setNeedsDisplay()
    }

    #endif

    public var theme: SyntaxColorTheme? {
        didSet {
            guard let theme = theme else {
                return
            }

            cachedThemeInfo = nil
            #if os(iOS)
            backgroundColor = theme.backgroundColor
            #endif
            textView.backgroundColor = theme.backgroundColor
            textView.theme = theme
            textView.font = theme.font

            refreshColors()
        }
    }

    var cachedThemeInfo: ThemeInfo?

    var themeInfo: ThemeInfo? {
        if let cached = cachedThemeInfo {
            return cached
        }

        guard let theme = theme else {
            return nil
        }

        let spaceAttrString = NSAttributedString(string: " ", attributes: [.font: theme.font])
        let spaceWidth = spaceAttrString.size().width

        let info = ThemeInfo(theme: theme, spaceWidth: spaceWidth)

        cachedThemeInfo = info

        return info
    }

    var cachedTokens: [CachedToken]?

    /// 当前缓存的 token 中是否含编辑器占位符(`<#...#>`,仅内置
    /// Swift / JS / Python / Java lexer 会产生;Mote 自定义的
    /// GenericCodeLexer 系语言不产生)。为 false 时,每次按键 /
    /// 选区变化对全量 token 的 O(n) 扫描与整段属性枚举全部跳过。
    private(set) var hasEditorPlaceholders = false

    /// 高亮调度代数:每次调度 +1;旧代数的后台词法结果回主线程时
    /// 若代数已变(期间又有新输入)则作废,杜绝过期 token 被应用。
    private var highlightGeneration: UInt = 0

    /// 同步高亮上限:低于它(小文档)保持"每次编辑立即同步高亮",
    /// 输入反馈零延迟;高于它(大文档)改为"防抖 + 后台词法分析",
    /// 避免粘贴/编辑大段文本时每敲一个键都在主线程全量重扫
    /// (实测 1.6MB 中文 md 一次全量高亮 ≈ 2s:逐 token 上属性
    /// 0.5s + 强制全文排版 1.3s)。
    private static let synchronousHighlightCharacterLimit = 32 * 1024

    /// 大文档高亮防抖间隔:输入停止这么久后才真正词法分析
    private static let highlightDebounceInterval: TimeInterval = 0.3

    func invalidateCachedTokens() {
        cachedTokens = nil
        hasEditorPlaceholders = false
    }

    /// 调度一次完整高亮刷新(词法分析 + 上属性)。
    ///
    /// - 小文档(≤ 同步高亮上限):主线程同步执行,行为与原先一致;
    /// - 大文档:防抖 0.3s 后把词法分析派到后台队列(正则匹配是
    ///   CPU 密集且与 UI 无关),完成后回主线程核对"代数未变且文本
    ///   未被继续修改"再应用属性,期间输入/滚动完全不被阻塞。
    func scheduleHighlight() {
        guard delegate != nil else {
            return
        }

        highlightGeneration &+= 1
        let generation = highlightGeneration
        let source = textView.text ?? ""
        guard !source.isEmpty else {
            return
        }

        if source.utf16.count <= Self.synchronousHighlightCharacterLimit {
            applyHighlight(source: source)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.highlightDebounceInterval) { [weak self] in
            guard let self = self, self.highlightGeneration == generation,
                  let delegate = self.delegate else {
                return
            }
            // lexer 获取很便宜(返回文档缓存的 lexer),留在主线程;
            // 真正贵的全文档正则匹配放到后台
            let lexer = delegate.lexerForSource(source)
            DispatchQueue.global(qos: .userInitiated).async {
                let tokens = lexer.getSavannaTokens(input: source)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.highlightGeneration == generation,
                          self.textView.text == source else {
                        return
                    }
                    self.applyTokens(tokens, source: source)
                }
            }
        }
    }

    /// 同步路径:词法分析 + 缓存 token + 上属性(主线程)
    private func applyHighlight(source: String) {
        let lexer = delegate!.lexerForSource(source)
        let tokens = lexer.getSavannaTokens(input: source)
        applyTokens(tokens, source: source)
    }

    /// 将一次词法结果应用到文本存储(主线程;词法本身可能在后台)
    private func applyTokens(_ tokens: [Token], source: String) {
        guard let theme = self.theme, let themeInfo = self.themeInfo else {
            return
        }

        let textStorage: NSTextStorage
        #if os(macOS)
        textStorage = textView.textStorage!
        #else
        textStorage = textView.textStorage
        #endif

        textView.font = theme.font

        let cachedTokens: [CachedToken] = tokens.map {
            let nsRange = source.nsRange(fromRange: $0.range)
            return CachedToken(token: $0, nsRange: nsRange)
        }

        self.cachedTokens = cachedTokens
        self.hasEditorPlaceholders = cachedTokens.contains { $0.token.isEditorPlaceholder }

        createAttributes(theme: theme, themeInfo: themeInfo, textStorage: textStorage, cachedTokens: cachedTokens, source: source)
    }

    func updateAttributes(textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

        // 无占位符的语言(含全部 Mote 自定义语言)无需在每次选区变化时
        // 枚举全文属性运行,直接跳过(O(n) → O(1))
        guard hasEditorPlaceholders else {
            return
        }

        let selectedRange = textView.selectedRange

        let fullRange = NSRange(location: 0, length: (source as NSString).length)

        var rangesToUpdate = [(NSRange, EditorPlaceholderState)]()

        textStorage.enumerateAttribute(.editorPlaceholder, in: fullRange, options: []) { (value, range, stop) in

            if let state = value as? EditorPlaceholderState {

                var newState: EditorPlaceholderState = .inactive

                if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
                    newState = .active
                }

                if newState != state {
                    rangesToUpdate.append((range, newState))
                }

            }

        }

        var didBeginEditing = false

        if !rangesToUpdate.isEmpty {
            textStorage.beginEditing()
            didBeginEditing = true
        }

        for (range, state) in rangesToUpdate {

            var attr = [NSAttributedString.Key: Any]()
            attr[.editorPlaceholder] = state

            textStorage.addAttributes(attr, range: range)

        }

        if didBeginEditing {
            textStorage.endEditing()
        }
    }

    func createAttributes(theme: SyntaxColorTheme, themeInfo: ThemeInfo, textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

        textStorage.beginEditing()

        var attributes = [NSAttributedString.Key: Any]()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 2.0
        paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
        paragraphStyle.tabStops = []

        let wholeRange = NSRange(location: 0, length: (source as NSString).length)

        attributes[.paragraphStyle] = paragraphStyle

        for (attr, value) in theme.globalAttributes() {

            attributes[attr] = value

        }

        textStorage.setAttributes(attributes, range: wholeRange)

        let selectedRange = textView.selectedRange

        for cachedToken in cachedTokens {

            let token = cachedToken.token

            if token.isPlain {
                continue
            }

            let range = cachedToken.nsRange

            if token.isEditorPlaceholder {

                let startRange = NSRange(location: range.lowerBound, length: 2)
                let endRange = NSRange(location: range.upperBound - 2, length: 2)

                let contentRange = NSRange(location: range.lowerBound + 2, length: range.length - 4)

                var attr = [NSAttributedString.Key: Any]()

                var state: EditorPlaceholderState = .inactive

                if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
                    state = .active
                }

                attr[.editorPlaceholder] = state

                textStorage.addAttributes(theme.attributes(for: token), range: contentRange)

                textStorage.addAttributes([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], range: startRange)
                textStorage.addAttributes([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], range: endRange)

                textStorage.addAttributes(attr, range: range)
                continue
            }

            textStorage.addAttributes(theme.attributes(for: token), range: range)
        }

        textStorage.endEditing()
    }

}

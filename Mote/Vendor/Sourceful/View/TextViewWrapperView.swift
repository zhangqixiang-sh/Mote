//
//  TextViewWrapperView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 17/02/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

#if os(macOS)
	
	class TextViewWrapperView: _View {
		
		override func hitTest(_ point: NSPoint) -> NSView? {
			// Disable interaction, so we're not blocking the text view.
			return nil
		}
		
		override func layout() {
			super.layout()
			
			self.setNeedsDisplay(self.bounds)
		}
		
		override func resize(withOldSuperviewSize oldSize: NSSize) {
			super.resize(withOldSuperviewSize: oldSize)
			
			self.textView?.invalidateCachedParagraphs()

			self.setNeedsDisplay(self.bounds)
			
		}
		
	var textView: InnerTextView?

	/// 超过该长度后,gutter 不再为全文生成段落矩形(那会强制 TextKit
	/// 排版全文,3MB 文档首次开窗约 10s),改为只按可见区域取 glyph range
	/// 并计算相交段落的行号。
	private static let visibleOnlyGutterCharacterLimit = 64 * 1024

	override public func draw(_ rect: CGRect) {

		guard let textView = textView else {
			return
		}

		guard let theme = textView.theme else {
			super.draw(rect)
			textView.hideGutter()
			return
		}

		if theme.lineNumbersStyle == nil {

			textView.hideGutter()

			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()

		} else {

			let contentHeight = textView.enclosingScrollView!.documentView!.bounds.height
			let yOffset = self.bounds.height - contentHeight
			let textLength = (textView.text as NSString).length

			let paragraphs: [Paragraph]
			if textLength > Self.visibleOnlyGutterCharacterLimit {
				paragraphs = visibleParagraphs(for: textView)
			} else if let cached = textView.cachedParagraphs {
				paragraphs = cached
			} else {
				paragraphs = generateParagraphs(for: textView, flipRects: true)
				textView.cachedParagraphs = paragraphs
			}

			let displayedParagraphs = offsetParagraphs(paragraphs, for: textView, yOffset: yOffset)
			let count = textView.lineCount
			let maxNumberOfDigits = "\(count)".count

			textView.updateGutterWidth(for: maxNumberOfDigits)

			theme.gutterStyle.backgroundColor.setFill()

			let gutterRect = CGRect(x: 0, y: 0, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()

			drawLineNumbers(displayedParagraphs, in: rect, for: textView)

		}

	}

	/// 大文档可见区行号:只 layout 可见 glyph range,不为全文排版。
	/// 返回值坐标已翻转为 wrapper 绘制坐标(尚未加 scrollView yOffset)。
	private func visibleParagraphs(for textView: InnerTextView) -> [Paragraph] {
		guard let layoutManager = textView.layoutManager,
			  let textContainer = textView.textContainer else {
			return []
		}

		let visibleRect = textView.visibleRect
		let lineHeight = (textView.font?.pointSize ?? 14) * 1.4
		var requestRect = visibleRect
		requestRect.origin.y -= lineHeight * 2
		requestRect.size.height += lineHeight * 4

		let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: requestRect, in: textContainer)
		let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
		let nsText = textView.text as NSString
		let paragraphRange = nsText.paragraphRange(for: visibleCharRange)

		var paragraphs: [Paragraph] = []
		var lastEnumeratedRect: CGRect?

		nsText.enumerateSubstrings(in: paragraphRange, options: [.byParagraphs]) { _, substringRange, _, _ in
			let rect = textView.paragraphRectForRange(range: substringRange)
			lastEnumeratedRect = rect
			guard rect.intersects(visibleRect) else { return }
			let number = textView.lineNumber(forCharacterOffset: substringRange.location)
			var paragraph = Paragraph(rect: rect, number: number)
			paragraph.rect.origin.y = textView.bounds.height - paragraph.rect.height - paragraph.rect.origin.y
			paragraphs.append(paragraph)
		}

		// 末尾空行:原文 generateParagraphs 对空文本/尾随换行会补一个
		// 行号矩形;仅当可见时才补,避免为全文状态付出额外布局。
		if textView.text.isEmpty || textView.text.hasSuffix("\n") {
			let gutterWidth = textView.textContainerInset.width
			let fallbackLineHeight: CGFloat = 18
			let endRect: CGRect
			if let last = lastEnumeratedRect {
				endRect = CGRect(x: 0,
								 y: last.origin.y + last.height + 2,
								 width: gutterWidth,
								 height: last.height)
			} else {
				endRect = CGRect(x: 0, y: 0, width: gutterWidth, height: fallbackLineHeight)
			}
			if endRect.intersects(visibleRect) {
				var endParagraph = Paragraph(rect: endRect, number: textView.lineCount)
				endParagraph.rect.origin.y = textView.bounds.height - endParagraph.rect.height - endParagraph.rect.origin.y
				paragraphs.append(endParagraph)
			}
		}

		return paragraphs
	}

}
	
#endif

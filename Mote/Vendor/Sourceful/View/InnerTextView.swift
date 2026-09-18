//
//  InnerTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 09/07/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

protocol InnerTextViewDelegate: AnyObject {
	func didUpdateCursorFloatingState()
}

class InnerTextView: TextView {
	
	weak var innerDelegate: InnerTextViewDelegate?
	
	var theme: SyntaxColorTheme?
	
	var cachedParagraphs: [Paragraph]?

	/// 行起始偏移(UTF-16)缓存:原先每次绘制 gutter 都对全文做
	/// `components(separatedBy: .newlines)`,大文档下等于每次滚动
	/// 都做一次 O(n) 字符串拷贝/切分;改为随文本变更只扫描一次换行符。
	/// 同时用于按可见区域绘制行号时的行号二分查找。
	private var cachedLineStartOffsets: [Int]?

	/// 当前文本的行数(惰性计算并缓存,文本变更时失效)
	var lineCount: Int {
		lineStartOffsets.count
	}

	/// 每行行首 UTF-16 偏移;首个偏移恒为 0,每个换行符后再记录一个偏移。
	/// CRLF 视为一个换行;行数语义与原 `components(separatedBy:.newlines).count` 一致。
	var lineStartOffsets: [Int] {
		if let cached = cachedLineStartOffsets {
			return cached
		}
		let nsText = text as NSString
		var starts = [0]
		var search = NSRange(location: 0, length: nsText.length)
		while search.length > 0 {
			let found = nsText.rangeOfCharacter(from: .newlines, range: search)
			guard found.location != NSNotFound else { break }
			var next = found.location + found.length
			// CRLF 合并为一个换行,避免在 \r 与 \n 之间生成一个空行行首
			if found.length == 1,
			   nsText.character(at: found.location) == 13, // CR
			   found.location + 1 < nsText.length,
			   nsText.character(at: found.location + 1) == 10 { // LF
				next = found.location + 2
			}
			starts.append(next)
			search.location = next
			search.length = nsText.length - next
		}
		cachedLineStartOffsets = starts
		return starts
	}

	/// 某个 UTF-16 字符偏移所在的 1-based 行号(二分查找行首偏移)
	func lineNumber(forCharacterOffset offset: Int) -> Int {
		let starts = lineStartOffsets
		var low = 0
		var high = starts.count - 1
		var answer = 0
		while low <= high {
			let mid = (low + high) / 2
			if starts[mid] <= offset {
				answer = mid
				low = mid + 1
			} else {
				high = mid - 1
			}
		}
		return answer + 1
	}

	func invalidateCachedParagraphs() {
		cachedParagraphs = nil
		cachedLineStartOffsets = nil
	}
	
	func hideGutter() {
		gutterWidth = theme?.gutterStyle.minimumWidth ?? 0.0
	}
	
	func updateGutterWidth(for numberOfCharacters: Int) {
		
		let leftInset: CGFloat = 4.0
		let rightInset: CGFloat = 4.0
		
		let charWidth: CGFloat = 10.0
		
		gutterWidth = max(theme?.gutterStyle.minimumWidth ?? 0.0, CGFloat(numberOfCharacters) * charWidth + leftInset + rightInset)
		
	}
	
	#if os(iOS)
	
	var isCursorFloating = false
	
	override func beginFloatingCursor(at point: CGPoint) {
		super.beginFloatingCursor(at: point)
		
		isCursorFloating = true
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
	override func endFloatingCursor() {
		super.endFloatingCursor()
		
		isCursorFloating = false
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
	override public func draw(_ rect: CGRect) {
		
		guard let theme = theme else {
			super.draw(rect)
			hideGutter()
			return
		}
		
		let textView = self

		if theme.lineNumbersStyle == nil  {

			hideGutter()

			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
		} else {
			
			let count = textView.lineCount

			let maxNumberOfDigits = "\(count)".count
			
			textView.updateGutterWidth(for: maxNumberOfDigits)
            
            var paragraphs: [Paragraph]
            
            if let cached = textView.cachedParagraphs {
                
                paragraphs = cached
                
            } else {
                
                paragraphs = generateParagraphs(for: textView, flipRects: false)
                textView.cachedParagraphs = paragraphs
                
            }
			
			theme.gutterStyle.backgroundColor.setFill()
			
			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
			drawLineNumbers(paragraphs, in: rect, for: self)
			
		}
		

		super.draw(rect)

	}
	#endif
	
	var gutterWidth: CGFloat {
		set {
			
			#if os(macOS)
				textContainerInset = NSSize(width: newValue, height: 0)
			#else
				textContainerInset = UIEdgeInsets(top: 0, left: newValue, bottom: 0, right: 0)
			#endif
			
		}
		get {
			
			#if os(macOS)
				return textContainerInset.width
			#else
				return textContainerInset.left
			#endif
			
		}
	}
//	var gutterWidth: CGFloat = 0.0 {
//		didSet {
//
//			textContainer.exclusionPaths = [UIBezierPath(rect: CGRect(x: 0.0, y: 0.0, width: gutterWidth, height: .greatestFiniteMagnitude))]
//
//		}
//
//	}
	
	#if os(iOS)
	
	override func caretRect(for position: UITextPosition) -> CGRect {
		
		var superRect = super.caretRect(for: position)
		
		guard let theme = theme else {
			return superRect
		}
		
		let font = theme.font
		
		// "descender" is expressed as a negative value,
		// so to add its height you must subtract its value
		superRect.size.height = font.pointSize - font.descender
		
		return superRect
	}
	
	#endif
	
}

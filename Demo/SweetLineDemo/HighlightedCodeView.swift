import SweetLine
import SwiftUI
import UIKit

struct HighlightedCodeView: UIViewRepresentable {
    let source: String
    let highlight: DocumentHighlight?
    let indentGuides: IndentGuideResult?
    let theme: HighlightTheme
    let onTextChange: (NSRange, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    func makeUIView(context: Context) -> IndentGuideContainerView {
        let container = IndentGuideContainerView()
        let textView = container.textView
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 14, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        return container
    }

    func updateUIView(_ container: IndentGuideContainerView, context: Context) {
        let textView = container.textView
        context.coordinator.onTextChange = onTextChange
        context.coordinator.source = source

        textView.backgroundColor = theme.backgroundUIColor
        container.backgroundColor = theme.backgroundUIColor
        textView.indicatorStyle = theme.isDark ? .white : .black
        textView.keyboardAppearance = theme.isDark ? .dark : .light
        textView.typingAttributes = Self.baseAttributes(theme: theme, font: Self.codeFont)

        let selectedRange = textView.selectedRange
        let contentOffset = textView.contentOffset
        let attributedText = Self.attributedString(source: source, highlight: highlight, theme: theme)

        context.coordinator.isApplyingHighlight = true
        textView.attributedText = attributedText
        textView.selectedRange = Self.clamped(range: selectedRange, length: attributedText.length)
        textView.setContentOffset(contentOffset, animated: false)
        container.updateIndentGuides(source: source, indentGuides: indentGuides, theme: theme, font: Self.codeFont)
        context.coordinator.isApplyingHighlight = false
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onTextChange: (NSRange, String) -> Void
        var source = ""
        var isApplyingHighlight = false
        private var pendingEdit: (range: NSRange, replacement: String)?

        init(onTextChange: @escaping (NSRange, String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingHighlight else { return true }
            pendingEdit = (range, text)
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingHighlight else { return }
            if let edit = pendingEdit {
                pendingEdit = nil
                onTextChange(edit.range, edit.replacement)
            } else {
                onTextChange(NSRange(location: 0, length: (source as NSString).length), textView.text ?? "")
            }
        }
    }

    private static let codeFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    private static func attributedString(source: String, highlight: DocumentHighlight?, theme: HighlightTheme) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: source,
            attributes: baseAttributes(theme: theme, font: codeFont)
        )

        guard let highlight else { return attributed }
        let lines = source.components(separatedBy: "\n")
        let lineStarts = utf16LineStarts(in: lines)

        for lineIndex in highlight.lines.indices {
            guard lineIndex < lines.count else { continue }
            for span in highlight.lines[lineIndex].spans {
                guard let nsRange = nsRange(for: span, lines: lines, lineStarts: lineStarts) else { continue }
                attributed.addAttributes(attributes(for: span.style, theme: theme), range: nsRange)
            }
        }

        return attributed
    }

    private static func baseAttributes(theme: HighlightTheme, font: UIFont) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1

        return [
            .font: font,
            .foregroundColor: theme.textUIColor,
            .paragraphStyle: paragraph,
        ]
    }

    private static func attributes(for style: TokenStyle, theme: HighlightTheme) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.foreground(for: style),
            .font: font(for: style),
        ]

        if case let .inline(inlineStyle) = style {
            if inlineStyle.background != 0 {
                attributes[.backgroundColor] = UIColor(argb: UInt32(bitPattern: inlineStyle.background))
            }
            if inlineStyle.isStrikethrough {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
        }

        return attributes
    }

    private static func font(for style: TokenStyle) -> UIFont {
        guard case let .inline(inlineStyle) = style else {
            return codeFont
        }

        var traits: UIFontDescriptor.SymbolicTraits = []
        if inlineStyle.isBold { traits.insert(.traitBold) }
        if inlineStyle.isItalic { traits.insert(.traitItalic) }
        guard !traits.isEmpty, let descriptor = codeFont.fontDescriptor.withSymbolicTraits(traits) else {
            return codeFont
        }
        return UIFont(descriptor: descriptor, size: codeFont.pointSize)
    }

    private static func nsRange(for span: TokenSpan, lines: [String], lineStarts: [Int]) -> NSRange? {
        let line = span.range.start.line
        guard lines.indices.contains(line), lineStarts.indices.contains(line) else { return nil }

        let lineText = lines[line]
        let startColumn = max(0, min(span.range.start.column, lineText.count))
        let endColumn = max(startColumn, min(span.range.end.column, lineText.count))
        guard let startOffset = utf16Offset(in: lineText, column: startColumn),
              let endOffset = utf16Offset(in: lineText, column: endColumn) else {
            return nil
        }

        return NSRange(location: lineStarts[line] + startOffset, length: endOffset - startOffset)
    }

    private static func utf16LineStarts(in lines: [String]) -> [Int] {
        var starts: [Int] = []
        starts.reserveCapacity(lines.count)
        var offset = 0
        for line in lines {
            starts.append(offset)
            offset += line.utf16.count + 1
        }
        return starts
    }

    private static func utf16Offset(in line: String, column: Int) -> Int? {
        let index = line.index(line.startIndex, offsetBy: min(column, line.count))
        guard let utf16Index = index.samePosition(in: line.utf16) else { return nil }
        return line.utf16.distance(from: line.utf16.startIndex, to: utf16Index)
    }

    private static func clamped(range: NSRange, length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        let upperBound = min(max(range.location + range.length, location), length)
        return NSRange(location: location, length: upperBound - location)
    }
}

final class IndentGuideContainerView: UIView {
    let textView = IndentGuideTextView()
    private let guideOverlay = IndentGuideOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        guideOverlay.frame = bounds
        bringSubviewToFront(guideOverlay)
        guideOverlay.refresh()
    }

    func updateIndentGuides(source: String, indentGuides: IndentGuideResult?, theme: HighlightTheme, font: UIFont) {
        guideOverlay.source = source
        guideOverlay.indentGuides = indentGuides
        guideOverlay.theme = theme
        guideOverlay.font = font
        guideOverlay.refresh()
    }

    private func configureViews() {
        textView.backgroundColor = .clear
        textView.onViewportChange = { [weak self] in
            self?.guideOverlay.refresh()
        }

        guideOverlay.isUserInteractionEnabled = false
        guideOverlay.textView = textView

        addSubview(textView)
        addSubview(guideOverlay)
    }
}

final class IndentGuideTextView: UITextView {
    var onViewportChange: (() -> Void)?

    override var contentOffset: CGPoint {
        didSet {
            onViewportChange?()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportChange?()
    }
}

private final class IndentGuideOverlayView: UIView {
    private let shapeLayer = CAShapeLayer()
    weak var textView: UITextView?
    var source = "" { didSet { refresh() } }
    var indentGuides: IndentGuideResult? { didSet { refresh() } }
    var theme = HighlightTheme.sweetLineDark() { didSet { refresh() } }
    var font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular) { didSet { refresh() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureShapeLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureShapeLayer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        updatePath()
    }

    func refresh() {
        setNeedsLayout()
        updatePath()
    }

    private func updatePath() {
        guard let textView, let indentGuides, !indentGuides.guideLines.isEmpty else {
            shapeLayer.path = nil
            return
        }
        guard bounds.width > 0, bounds.height > 0 else {
            shapeLayer.path = nil
            return
        }

        let lines = source.components(separatedBy: "\n")
        let lineStarts = Self.utf16LineStarts(in: lines)
        guard !lineStarts.isEmpty else {
            shapeLayer.path = nil
            return
        }

        textView.layoutManager.ensureLayout(for: textView.textContainer)

        let path = UIBezierPath()
        let guideColor = theme.textUIColor.blended(with: theme.backgroundUIColor, ratio: 0.35)
        let charWidth = NSString(string: " ").size(withAttributes: [.font: font]).width
        let contentOffset = textView.contentOffset
        let codeX = textView.textContainerInset.left + textView.textContainer.lineFragmentPadding
        let maxLine = lineStarts.count - 1

        for guide in indentGuides.guideLines {
            let firstLine = max(0, guide.continuesBefore ? guide.startLine : guide.startLine + 1)
            let lastLine = min(maxLine, guide.continuesAfter ? guide.endLine : guide.endLine - 1)
            guard firstLine <= lastLine else { continue }
            guard let startFrame = lineFrame(line: firstLine, lineStarts: lineStarts, textView: textView),
                  let endFrame = lineFrame(line: lastLine, lineStarts: lineStarts, textView: textView) else {
                continue
            }

            let x = codeX + CGFloat(guide.column) * charWidth - contentOffset.x
            path.move(to: CGPoint(x: x, y: startFrame.minY))
            path.addLine(to: CGPoint(x: x, y: endFrame.maxY))

            for branch in guide.branches where branch.line >= firstLine && branch.line <= lastLine {
                guard let branchFrame = lineFrame(line: branch.line, lineStarts: lineStarts, textView: textView) else {
                    continue
                }
                let branchX = codeX + CGFloat(branch.column) * charWidth - contentOffset.x
                let branchY = branchFrame.midY
                path.move(to: CGPoint(x: min(x, branchX), y: branchY))
                path.addLine(to: CGPoint(x: max(x, branchX), y: branchY))
            }
        }

        let displayScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 1
        shapeLayer.strokeColor = guideColor.cgColor
        shapeLayer.lineDashPattern = [2, 3]
        shapeLayer.lineWidth = 1 / displayScale
        shapeLayer.path = path.cgPath
    }

    private func configureShapeLayer() {
        isOpaque = false
        backgroundColor = .clear
        layer.zPosition = 1
        shapeLayer.fillColor = nil
        shapeLayer.lineCap = .round
        shapeLayer.zPosition = 1
        layer.addSublayer(shapeLayer)
    }

    private func lineFrame(line: Int, lineStarts: [Int], textView: UITextView) -> CGRect? {
        guard lineStarts.indices.contains(line) else { return nil }

        let layoutManager = textView.layoutManager
        let textStorageLength = textView.textStorage.length
        guard textStorageLength > 0 else { return nil }

        let characterIndex = min(lineStarts[line], textStorageLength - 1)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: characterIndex, length: 1),
            actualCharacterRange: nil
        )
        guard glyphRange.location != NSNotFound else { return nil }

        let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        return fragment.offsetBy(
            dx: textView.textContainerInset.left - textView.contentOffset.x,
            dy: textView.textContainerInset.top - textView.contentOffset.y
        )
    }


    private static func utf16LineStarts(in lines: [String]) -> [Int] {
        var starts: [Int] = []
        starts.reserveCapacity(lines.count)
        var offset = 0
        for line in lines {
            starts.append(offset)
            offset += line.utf16.count + 1
        }
        return starts
    }
}

private extension UIColor {
    convenience init(argb: UInt32) {
        let alpha = CGFloat((argb >> 24) & 0xFF) / 255.0
        let red = CGFloat((argb >> 16) & 0xFF) / 255.0
        let green = CGFloat((argb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(argb & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    func blended(with other: UIColor, ratio: CGFloat) -> UIColor {
        var firstRed: CGFloat = 0
        var firstGreen: CGFloat = 0
        var firstBlue: CGFloat = 0
        var firstAlpha: CGFloat = 0
        var secondRed: CGFloat = 0
        var secondGreen: CGFloat = 0
        var secondBlue: CGFloat = 0
        var secondAlpha: CGFloat = 0

        getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha)
        other.getRed(&secondRed, green: &secondGreen, blue: &secondBlue, alpha: &secondAlpha)

        return UIColor(
            red: firstRed * ratio + secondRed * (1 - ratio),
            green: firstGreen * ratio + secondGreen * (1 - ratio),
            blue: firstBlue * ratio + secondBlue * (1 - ratio),
            alpha: firstAlpha * ratio + secondAlpha * (1 - ratio)
        )
    }
}

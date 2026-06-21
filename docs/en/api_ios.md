# SweetLine iOS Swift API

This document describes the Swift Package SDK in this repository.

## Overview

- Module: `SweetLine`
- Platform: iOS 14+
- Binding style: Swift API over the SweetLine C API and bundled `SweetLineCoreIOS.xcframework`
- Demo project: `Demo` (SwiftUI/UIKit)
- Package version: `1.2.4`

## Install

For local development, add the `SweetLine-iOS` repository root as a local Swift Package dependency from an iOS app project:

```text
SweetLine-iOS
```

Then import the public SDK module:

```swift
import SweetLine
```

## Native Artifact

The package uses a local binary target:

```swift
.binaryTarget(
    name: "SweetLineCoreIOS",
    path: "Vendor/iOS/SweetLineCoreIOS.xcframework"
)
```

Refresh the bundled artifact from the repository root:

```bash
scripts/build-shared.sh --platform ios
Scripts/sync-native.sh
```

This refreshes the bundled dynamic `SweetLineCoreIOS.xcframework` for SwiftPM/Xcode consumers and keeps per-architecture `libsweetline.dylib` outputs under `prebuilt/ios/<arch>/` for native consumers such as KMP.

For remote SwiftPM distribution, publish `SweetLineCoreIOS.xcframework.zip` as a release artifact and replace the local binary target with a URL plus checksum.

## Core Types

- `HighlightConfig(showIndex:inlineStyle:)`
- `HighlightEngine`
- `TextAnalyzer`
- `Document`
- `DocumentAnalyzer`
- `TextPosition`, `TextRange`, `TextLineInfo`, `LineRange`
- `TokenStyle`, `TokenSpan`, `LineHighlight`, `DocumentHighlight`
- `DocumentHighlightSlice`
- `BracketTokenKind`, `BracketMatchState`, `BracketToken`, `LineBracketPairs`, `BracketPairResult`
- `IndentGuideLine`, `IndentGuideResult`, `LineScopeState`
- `SweetLineError`, `SyntaxCompileError`

## HighlightEngine

```swift
public final class HighlightEngine {
    public init(config: HighlightConfig = HighlightConfig()) throws

    public func registerStyleName(_ styleName: String, id styleId: Int32) throws
    public func getStyleName(id styleId: Int32) throws -> String?
    public func defineMacro(_ macroName: String) throws
    public func undefineMacro(_ macroName: String) throws

    public func compileSyntax(fromJson syntaxJson: String) throws
    public func compileSyntax(fromFile path: String) throws

    public func createAnalyzer(syntaxName: String) throws -> TextAnalyzer?
    public func createAnalyzer(fileName: String) throws -> TextAnalyzer?
    public func loadDocument(_ document: Document) throws -> DocumentAnalyzer?

    public func close()
}
```

## TextAnalyzer

```swift
public final class TextAnalyzer {
    public func analyzeText(_ text: String) throws -> DocumentHighlight
    public func analyzeLine(_ text: String, info: TextLineInfo) throws -> LineAnalyzeResult
    public func analyzeIndentGuides(_ text: String) throws -> IndentGuideResult
    public func analyzeBracketPairs(_ text: String) throws -> BracketPairResult
    public func close()
}
```

## DocumentAnalyzer

```swift
public final class DocumentAnalyzer {
    public func analyze() throws -> DocumentHighlight
    public func analyzeLineRange(_ visibleRange: LineRange) throws -> DocumentHighlightSlice
    public func analyzeIncremental(range: TextRange, newText: String) throws -> DocumentHighlight
    public func analyzeIncrementalInLineRange(
        range: TextRange,
        newText: String,
        visibleRange: LineRange
    ) throws -> DocumentHighlightSlice
    public func getHighlightSlice(_ visibleRange: LineRange) throws -> DocumentHighlightSlice
    public func analyzeIndentGuides() throws -> IndentGuideResult
    public func analyzeIndentGuidesInLineRange(_ visibleRange: LineRange) throws -> IndentGuideResult
    public func analyzeBracketPairs() throws -> BracketPairResult
    public func analyzeBracketPairsInLineRange(_ visibleRange: LineRange) throws -> BracketPairResult
    public func close()
}
```

`analyzeLineRange(...)` analyzes enough lines from the current managed document state to satisfy the requested visible range.
`analyzeIncrementalInLineRange(...)` applies a patch and immediately returns the requested slice.
`getHighlightSlice(...)` reads a visible slice from the latest cached result after `analyze()` or `analyzeIncremental(...)`.

## SyntaxCompileError

`SyntaxCompileError` exposes the same compile error code constants as the Java 22 and C# desktop bindings:

```swift
SyntaxCompileError.ok
SyntaxCompileError.jsonPropertyMissed
SyntaxCompileError.jsonPropertyInvalid
SyntaxCompileError.patternInvalid
SyntaxCompileError.stateInvalid
SyntaxCompileError.jsonInvalid
SyntaxCompileError.fileNotExists
SyntaxCompileError.fileInvalid
SyntaxCompileError.importSyntaxNotFound
SyntaxCompileError.stateReferenceNotFound
SyntaxCompileError.inlineStyleReferenceNotFound
```

## Complete Example

```swift
import SweetLine

let sourceCode = "struct Demo { let value = 1 }"
let syntaxJson = """
{
  "name": "swift",
  "fileSuffixes": [".swift"],
  "states": {
    "default": [
      { "pattern": "\\\\b(struct|let)\\\\b", "style": "keyword" }
    ]
  }
}
"""

let engine = try HighlightEngine(config: HighlightConfig(showIndex: true, inlineStyle: false))
defer { engine.close() }

try engine.registerStyleName("keyword", id: 1)
try engine.registerStyleName("string", id: 2)
try engine.compileSyntax(fromJson: syntaxJson)

if let textAnalyzer = try engine.createAnalyzer(fileName: "Demo.swift") {
    let preview = try textAnalyzer.analyzeText(sourceCode)
    let line = try textAnalyzer.analyzeLine(sourceCode, info: TextLineInfo(line: 0))
    let guides = try textAnalyzer.analyzeIndentGuides(sourceCode)
    let brackets = try textAnalyzer.analyzeBracketPairs(sourceCode)
    _ = (preview, line, guides, brackets)
    textAnalyzer.close()
}

let document = try Document(uri: "file:///Demo.swift", text: sourceCode)
defer { document.close() }

if let analyzer = try engine.loadDocument(document) {
    let initial = try analyzer.analyze()
    let change = TextRange(
        start: TextPosition(line: 0, column: 7),
        end: TextPosition(line: 0, column: 11)
    )
    let updated = try analyzer.analyzeIncremental(range: change, newText: "Sample")
    let cachedVisible = try analyzer.getHighlightSlice(LineRange(startLine: 0, lineCount: 80))
    let visible = try analyzer.analyzeIncrementalInLineRange(
        range: change,
        newText: "Sample",
        visibleRange: LineRange(startLine: 0, lineCount: 80)
    )
    let indentGuides = try analyzer.analyzeIndentGuides()
    let visibleIndentGuides = try analyzer.analyzeIndentGuidesInLineRange(LineRange(startLine: 0, lineCount: 80))
    let brackets = try analyzer.analyzeBracketPairs()
    let visibleBrackets = try analyzer.analyzeBracketPairsInLineRange(LineRange(startLine: 0, lineCount: 80))
    _ = (initial, updated, cachedVisible, visible, indentGuides, visibleIndentGuides, brackets, visibleBrackets)
    analyzer.close()
}
```

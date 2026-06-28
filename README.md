# SweetLine for iOS

SweetLine for iOS is a Swift Package SDK over the SweetLine native core.

The main SweetLine monorepo is available at [FinalScave/SweetLine](https://github.com/FinalScave/SweetLine).

## Install

For local development, add this folder as a local Swift Package dependency from an iOS app project:

```text
platform/iOS
```

Then import the public SDK module:

```swift
import SweetLine
```

## Native Artifact

The published Swift Package resolves the native core from the GitHub release asset:

```swift
.binaryTarget(
    name: "SweetLineCoreIOS",
    url: "https://github.com/Xiue233/SweetLine-iOS/releases/download/v1.3.1/SweetLineCoreIOS.xcframework.zip",
    checksum: "45bcf3f36e0b23d2c4757f8681aea7d22c2489510da51ec8dd7e090dde568cc8"
)
```

For repo-local refresh and validation, rebuild from the repository root and then sync the bundled vendor copy:

```bash
scripts/build-shared.sh --platform ios
platform/iOS/Scripts/sync-native.sh
```

That flow refreshes all iOS release artifacts together:

- `prebuilt/ios/arm64/libsweetline.dylib`
- `prebuilt/ios/simulator-arm64/libsweetline.dylib`
- `prebuilt/ios/arm64/SweetLineCore.framework.zip`
- `prebuilt/ios/simulator-arm64/SweetLineCore.framework.zip`
- `prebuilt/ios/SweetLineCoreIOS.xcframework.zip`
- `platform/iOS/Vendor/iOS/SweetLineCoreIOS.xcframework`

`SweetLineCoreIOS.xcframework.zip` is the SwiftPM release artifact. The per-architecture `dylib` and framework archives remain available for native consumers and manual inspection.

## Usage

```swift
import SweetLine

let engine = try HighlightEngine(config: HighlightConfig(showIndex: true, inlineStyle: false))
try engine.registerStyleName("keyword", id: 1)
try engine.registerStyleName("string", id: 2)
try engine.compileSyntax(fromJson: syntaxJson)

let analyzer = try engine.createAnalyzer(fileName: "main.swift")
let highlight = try analyzer?.analyzeText("let value = 1")

let document = try Document(uri: "file:///main.swift", text: "let value = 1")
defer { document.close() }

let documentAnalyzer = try engine.loadDocument(document)
let full = try documentAnalyzer?.analyze()
let guides = try documentAnalyzer?.analyzeIndentGuides()
let visibleGuides = try documentAnalyzer?.analyzeIndentGuidesInLineRange(LineRange(startLine: 0, lineCount: 80))
let brackets = try documentAnalyzer?.analyzeBracketPairs()
let visibleBrackets = try documentAnalyzer?.analyzeBracketPairsInLineRange(LineRange(startLine: 0, lineCount: 80))
let updated = try documentAnalyzer?.analyzeIncremental(
    range: TextRange(
        start: TextPosition(line: 0, column: 4),
        end: TextPosition(line: 0, column: 9)
    ),
    newText: "answer"
)
let visible = try documentAnalyzer?.getHighlightSlice(LineRange(startLine: 0, lineCount: 80))
```

## Core Types

- `HighlightConfig(showIndex:inlineStyle:)`
- `HighlightEngine`
- `TextAnalyzer`
- `Document`
- `DocumentAnalyzer`
- `TextPosition`, `TextRange`, `TextLineInfo`, `LineRange`
- `TokenSpan`, `LineHighlight`, `DocumentHighlight`, `DocumentHighlightSlice`
- `IndentGuideLine`, `IndentGuideResult`, `LineScopeState`
- `BracketTokenKind`, `BracketMatchState`, `BracketToken`, `LineBracketPairs`, `BracketPairResult`
- `SyntaxCompileError`

## Layout

```text
Package.swift
Sources/SweetLine/
  SweetLine.swift
  SweetLineNative.swift
  NativeBufferParser.swift
  HighlightEngine.swift
  TextAnalyzer.swift
  Document.swift
  DocumentAnalyzer.swift
  Models.swift
  Errors.swift
Vendor/iOS/SweetLineCoreIOS.xcframework
Tests/SweetLineTests/
Demo/
prebuilt/ios/arm64/libsweetline.dylib
prebuilt/ios/simulator-arm64/libsweetline.dylib
```

The demo app lives in `platform/iOS/Demo` and consumes this package as a local Swift Package dependency.

//
//  Key.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

enum ShiftState: Equatable {
    case unshifted
    case shifted
    case capsLock
}

enum RepeatingBehavior: Equatable {
    case repeating
}

enum LongPressBehavior: Equatable {
    case repeating
    case alternates([String])
}

enum DoubleTapBehavior: Equatable {
    case capsLock
}

enum FeedbackPattern: Equatable {
    case subtle
    case light
    case selection
    case none
}

enum KeyType: Equatable {
    case simple(String)
    case backspace
    case shift
    case enter
    case space
    case layerSwitch(Layer)
    case layoutSwitch(KeyboardLayout)
    case globe
    case empty
}

struct Key {
    let keyType: KeyType
    let longPressBehavior: LongPressBehavior?
    let doubleTapBehavior: DoubleTapBehavior?

    init(_ keyType: KeyType, longPressBehavior: LongPressBehavior? = nil, doubleTapBehavior: DoubleTapBehavior? = nil) {
        self.keyType = keyType
        self.longPressBehavior = longPressBehavior
        self.doubleTapBehavior = doubleTapBehavior
    }

    static func shouldUnspacePunctuation(_ text: String) -> Bool {
        let unspacingCharacters: Set<Character> = [".", ",", "!", "?", ":", ";", ")", "]", "}", "'", "\"", "—", "…"]
        return text.count == 1 && unspacingCharacters.contains(text.first!)
    }

    static func shouldAddTrailingSpaceAfterPunctuation(_ text: String) -> Bool {
        let noTrailingSpaceCharacters: Set<Character> = ["—"]
        return !(text.count == 1 && noTrailingSpaceCharacters.contains(text.first!))
    }

    static func shouldTriggerAutocorrect(_ text: String) -> Bool {
        // Trigger autocorrect for punctuation that ends words, but not for apostrophe
        // since apostrophe may be part of contractions that aren't complete yet
        let autocorrectTriggers: Set<Character> = [".", ",", "!", "?", ":", ";", ")", "]", "}", "\"", "—", "…"]
        return text.count == 1 && autocorrectTriggers.contains(text.first!)
    }

    static func autocorrectWord(_ word: String, using predictionService: PredictionService) -> String {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return word }

        return predictionService.correctTypo(word: trimmedWord) ?? word
    }

    static func getCurrentWord(from textDocumentProxy: UITextDocumentProxy) -> (word: String, range: NSRange)? {
        guard let beforeInput = textDocumentProxy.documentContextBeforeInput else {
            return nil
        }

        // Find the start of the current word by looking backward from cursor
        var wordStart = beforeInput.count
        for (index, char) in beforeInput.reversed().enumerated() {
            if char.isWhitespace || char.isPunctuation {
                wordStart = beforeInput.count - index
                break
            }
            if index == beforeInput.count - 1 {
                wordStart = 0
            }
        }

        // Extract the current word
        let wordStartIndex = beforeInput.index(beforeInput.startIndex, offsetBy: wordStart)
        let currentWord = String(beforeInput[wordStartIndex...])

        if currentWord.isEmpty {
            return nil
        }

        return (word: currentWord, range: NSRange(location: wordStart, length: currentWord.count))
    }

    static func replaceCurrentWord(in textDocumentProxy: UITextDocumentProxy, with newWord: String) {
        guard let wordInfo = getCurrentWord(from: textDocumentProxy) else { return }

        // Delete the current word
        for _ in 0..<wordInfo.word.count {
            textDocumentProxy.deleteBackward()
        }

        // Insert the corrected word
        textDocumentProxy.insertText(newWord)
    }

    static func applyAutocorrectWithVisual(to textDocumentProxy: UITextDocumentProxy, at position: CGPoint, using predictionService: PredictionService, visualHandler: @escaping (String, String, CGPoint) -> Void) {
        guard let wordInfo = getCurrentWord(from: textDocumentProxy) else { return }
        let correctedWord = autocorrectWord(wordInfo.word, using: predictionService)

        // Only show visual feedback and apply correction if the word actually changed
        if correctedWord != wordInfo.word {
            visualHandler(wordInfo.word, correctedWord, position)
            replaceCurrentWord(in: textDocumentProxy, with: correctedWord)
        }
    }

    func didTap(textDocumentProxy: UITextDocumentProxy, predictionService: PredictionService, layerSwitchHandler: @escaping (Layer) -> Void, layoutSwitchHandler: @escaping (KeyboardLayout) -> Void, shiftHandler: @escaping () -> Void, autoUnshiftHandler: @escaping () -> Void, globeHandler: @escaping () -> Void, maybePunctuating: Bool, autocorrectEnabled: Bool = true, autocorrectVisualHandler: @escaping (String, String, CGPoint) -> Void = { _, _, _ in }) {
        // Handle the key action
        switch keyType {
        case .simple(let text):
            // Check if this character should trigger autocorrect
            if autocorrectEnabled && Key.shouldTriggerAutocorrect(text) {
                // Apply autocorrect with visual feedback
                Key.applyAutocorrectWithVisual(to: textDocumentProxy, at: CGPoint(x: 0, y: 0), using: predictionService, visualHandler: autocorrectVisualHandler)
            }

            // Handle spacing for punctuation
            if Key.shouldUnspacePunctuation(text) {
                if maybePunctuating {
                    textDocumentProxy.deleteBackward()
                }
                let trailingSpace = (maybePunctuating && Key.shouldAddTrailingSpaceAfterPunctuation(text)) ? " " : ""
                textDocumentProxy.insertText(text + trailingSpace)
            } else {
                textDocumentProxy.insertText(text)
            }
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .shift:
            shiftHandler()
        case .enter:
            // Apply autocorrect with visual feedback before line break
            if autocorrectEnabled {
                Key.applyAutocorrectWithVisual(to: textDocumentProxy, at: CGPoint(x: 0, y: 0), using: predictionService, visualHandler: autocorrectVisualHandler)
            }
            textDocumentProxy.insertText("\n")
        case .space:
            // Apply autocorrect with visual feedback before inserting space
            if autocorrectEnabled {
                Key.applyAutocorrectWithVisual(to: textDocumentProxy, at: CGPoint(x: 0, y: 0), using: predictionService, visualHandler: autocorrectVisualHandler)
            }
            textDocumentProxy.insertText(" ")
        case .layerSwitch(let layer):
            layerSwitchHandler(layer)
        case .layoutSwitch(let layout):
            layoutSwitchHandler(layout)
        case .globe:
            globeHandler()
        case .empty:
            // Do nothing for empty keys
            break
        }

        // Handle auto-unshift for all keys except shift
        switch keyType {
        case .shift:
            break
        case .simple, .backspace, .enter, .space, .layerSwitch, .layoutSwitch, .globe:
            autoUnshiftHandler()
        case .empty:
            break
        }
    }

    func sfSymbolName(shiftState: ShiftState = .unshifted, pressed: Bool = false) -> String? {
        switch keyType {
        case .globe:
            return "globe"
        case .shift:
            switch shiftState {
            case .unshifted:
                return "shift"
            case .shifted:
                return "shift.fill"
            case .capsLock:
                return "capslock.fill"
            }
        case .backspace:
            return pressed ? "delete.backward.fill" : "delete.backward"
        default:
            return nil
        }
    }

    func label(shiftState: ShiftState) -> String {
        switch keyType {
        case .simple(let text):
            return text
        case .backspace:
            return "⌫" // Fallback if SF Symbol rendering fails
        case .shift:
            switch shiftState {
            case .unshifted:
                return "⇧" // Fallback if SF Symbol rendering fails
            case .shifted:
                return "⬆︎" // Fallback if SF Symbol rendering fails
            case .capsLock:
                return "⇪" // Fallback if SF Symbol rendering fails
            }
        case .enter:
            return "↩︎"
        case .space:
            return ""
        case .layerSwitch(let layer):
            switch layer {
            case .symbol:
                return "λ"
            case .number:
                return "#"
            case .alpha:
                return "ABC"
            }
        case .layoutSwitch(let layout):
            switch layout {
            case .canary:
                return "CAN"
            case .qwerty:
                return "QWE"
            }
        case .globe:
            return "◉" // Fallback if SF Symbol rendering fails
        case .empty:
            return ""
        }
    }

    func fontSize() -> CGFloat {
        switch keyType {
        case .simple, .space, .empty:
            return 22
        case .backspace, .shift, .enter:
            return 16
        case .globe:
            return 12
        case .layerSwitch:
            let labelText = self.label(shiftState: .unshifted)
            return labelText.count > 1 ? 12 : 16
        case .layoutSwitch:
            return 12
        }
    }

    func fontSize(deviceLayout: DeviceLayout) -> CGFloat {
        switch keyType {
        case .simple, .space, .empty:
            return deviceLayout.regularFontSize
        case .backspace, .shift, .enter:
            return deviceLayout.specialFontSize
        case .globe:
            return deviceLayout.smallFontSize
        case .layerSwitch:
            let labelText = self.label(shiftState: .unshifted)
            return labelText.count > 1 ? deviceLayout.smallFontSize : deviceLayout.specialFontSize
        case .layoutSwitch:
            return deviceLayout.smallFontSize
        }
    }

    func backgroundColor(shiftState: ShiftState, traitCollection: UITraitCollection, tapped: Bool = false, isLargeScreen: Bool = false) -> UIColor {
        let theme = ColorTheme.current(for: traitCollection)

        switch keyType {
        case .simple:
            return tapped ? (isLargeScreen ? theme.secondaryKeyColor : theme.primaryKeyColor) : theme.primaryKeyColor
        case .space:
            return tapped ? theme.secondaryKeyColor : theme.primaryKeyColor
        case .shift:
            switch shiftState {
            case .unshifted:
                return tapped ? theme.primaryKeyColor : theme.secondaryKeyColor
            case .shifted, .capsLock:
                return tapped ? theme.secondaryKeyColor : theme.primaryKeyColor
            }
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return tapped ? theme.primaryKeyColor : theme.secondaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func feedbackPattern() -> FeedbackPattern {
        switch keyType {
        case .simple, .shift, .layerSwitch, .layoutSwitch:
            return .subtle
        case .space, .enter:
            return .light
        case .backspace:
            return .selection
        case .globe, .empty:
            return .none
        }
    }

    func shouldResetMaybePunctuating() -> Bool {
        switch keyType {
        case .simple, .backspace, .enter, .space:
            return true
        case .shift, .layerSwitch, .layoutSwitch, .globe, .empty:
            return false
        }
    }
}

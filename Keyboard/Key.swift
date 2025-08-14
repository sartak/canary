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

enum Configuration: Equatable {
    case toggleAutocorrect
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
    case configuration(Configuration)
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

    static func getCurrentWord(from textDocumentProxy: UITextDocumentProxy) -> (word: String, range: NSRange)? {
        guard let beforeInput = textDocumentProxy.documentContextBeforeInput else {
            return nil
        }

        // Find the start of the current word by looking backward from cursor
        var wordStart = beforeInput.count
        for (index, _) in beforeInput.reversed().enumerated() {
            let currentIndex = beforeInput.index(beforeInput.endIndex, offsetBy: -(index + 1))
            if !SuggestionService.isWordCharacter(in: beforeInput, at: currentIndex) {
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

    static func applyAutocorrect(to textDocumentProxy: UITextDocumentProxy, using suggestionService: SuggestionService) {
        if let correctedWord = suggestionService.currentCorrection {
            replaceCurrentWord(in: textDocumentProxy, with: correctedWord)
        }
    }

    func didTap(textDocumentProxy: UITextDocumentProxy, suggestionService: SuggestionService, layerSwitchHandler: @escaping (Layer) -> Void, layoutSwitchHandler: @escaping (KeyboardLayout) -> Void, shiftHandler: @escaping () -> Void, autoUnshiftHandler: @escaping () -> Void, globeHandler: @escaping () -> Void, configurationHandler: @escaping (Configuration) -> Void, maybePunctuating: Bool, autocorrectEnabled: Bool = true) {
        // Handle the key action
        switch keyType {
        case .simple(let text):
            // Check if this character should trigger autocorrect
            if autocorrectEnabled && Key.shouldTriggerAutocorrect(text) {
                Key.applyAutocorrect(to: textDocumentProxy, using: suggestionService)
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
            if autocorrectEnabled {
                Key.applyAutocorrect(to: textDocumentProxy, using: suggestionService)
            }
            textDocumentProxy.insertText("\n")
        case .space:
            if autocorrectEnabled {
                Key.applyAutocorrect(to: textDocumentProxy, using: suggestionService)
            }
            textDocumentProxy.insertText(" ")
        case .layerSwitch(let layer):
            layerSwitchHandler(layer)
        case .layoutSwitch(let layout):
            layoutSwitchHandler(layout)
        case .globe:
            globeHandler()
        case .configuration(let config):
            configurationHandler(config)
        case .empty:
            // Do nothing for empty keys
            break
        }

        // Handle auto-unshift for all keys except shift
        switch keyType {
        case .shift:
            break
        case .simple, .backspace, .enter, .space, .layerSwitch, .layoutSwitch, .globe, .configuration:
            autoUnshiftHandler()
        case .empty:
            break
        }
    }

    func sfSymbolName(shiftState: ShiftState = .unshifted, pressed: Bool = false, autocorrectEnabled: Bool = true) -> String? {
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
        case .configuration(let config):
            switch config {
            case .toggleAutocorrect:
                return autocorrectEnabled ? "checkmark.circle" : "checkmark.circle.badge.xmark"
            }
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
        case .configuration(let config):
            switch config {
            case .toggleAutocorrect:
                return "AC"
            }
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
        case .configuration:
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
        case .configuration:
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
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe, .configuration:
            return tapped ? theme.primaryKeyColor : theme.secondaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func feedbackPattern() -> FeedbackPattern {
        switch keyType {
        case .simple, .shift, .layerSwitch, .layoutSwitch, .configuration:
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
        case .shift, .layerSwitch, .layoutSwitch, .globe, .configuration, .empty:
            return false
        }
    }
}

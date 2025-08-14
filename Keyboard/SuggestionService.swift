import Foundation
import SQLite3

protocol SuggestionServiceDelegate: AnyObject {
    func suggestionService(_ service: SuggestionService, didUpdateSuggestions typeahead: [(String, [InputAction])], autocorrect: String?)
}

enum InputAction {
    case insert(String)
    case moveCursor(Int)  // positive = forward, negative = backward
    case maybePunctuating(Bool)
    case deleteBackward
}

class SuggestionService {
    weak var delegate: SuggestionServiceDelegate?

    private var contextBefore: String?
    private var contextAfter: String?
    private var selectedText: String?

    private var typeaheadService: TypeaheadService

    private var autocorrectService: AutocorrectService
    private let db: OpaquePointer
    var autocorrectSuggestion: String?
    var autocorrectActions: [InputAction]?

    init?() {
        guard let path = Bundle(for: SuggestionService.self).path(forResource: "words", ofType: "db") else {
            return nil
        }

        var dbTemp: OpaquePointer?
        if sqlite3_open(path, &dbTemp) != SQLITE_OK {
            print("SuggestionService: Error opening database: \(String(cString: sqlite3_errmsg(dbTemp)))")
            if dbTemp != nil {
                sqlite3_close(dbTemp)
            }
            return nil
        }

        guard let db = dbTemp else {
            return nil
        }
        self.db = db

        let autocorrectService = AutocorrectService(db: db)
        guard let typeaheadService = TypeaheadService(db: db) else {
            sqlite3_close(db)
            return nil
        }

        self.autocorrectService = autocorrectService
        self.typeaheadService = typeaheadService
    }

    deinit {
        sqlite3_close(db)
    }

    func updateContext(before: String?, after: String?, selected: String?, autocorrectEnabled: Bool) {
        self.contextBefore = before
        self.contextAfter = after
        self.selectedText = selected

        let (prefix, suffix) = extractCurrentWordContext()

        let (typeahead, exactMatch) = updateTypeahead(prefix: prefix, suffix: suffix)

        if autocorrectEnabled {
            if let exactMatch = exactMatch {
                // We have an exact match, do smart capitalization
                let smartCapitalizedWord = applySmartCapitalization(word: exactMatch, userPrefix: prefix, userSuffix: suffix)
                autocorrectSuggestion = smartCapitalizedWord != (prefix + suffix) ? smartCapitalizedWord : nil
            } else {
                // No exact match, proceed with autocorrect
                autocorrectSuggestion = updateAutocorrect(prefix: prefix, suffix: suffix, autocorrectEnabled: autocorrectEnabled)
            }
        } else {
            autocorrectSuggestion = nil
        }

        autocorrectActions = autocorrectSuggestion != nil ? createInputActions(for: autocorrectSuggestion!, prefix: prefix, suffix: suffix, excludeTrailingSpace: true) : nil

        let filteredTypeahead = if let correction = autocorrectSuggestion {
            typeahead.filter { $0.0 != correction }
        } else {
            typeahead
        }

        delegate?.suggestionService(self, didUpdateSuggestions: filteredTypeahead, autocorrect: autocorrectSuggestion)
    }

    private func updateAutocorrect(prefix: String, suffix: String, autocorrectEnabled: Bool = true) -> String? {
        if prefix.isEmpty || !autocorrectEnabled {
            return nil
        }

        // Skip correction for strings containing invalid characters
        // Only allow words composed entirely of valid word characters
        if !prefix.indices.allSatisfy({ index in
            Self.isWordCharacter(in: prefix, at: index)
        }) {
            return nil
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let correction = autocorrectService.findBestCorrection(for: prefix.lowercased(), maxDistance: 2)
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds

        if let correction = correction {
            let correction = applySmartCapitalization(word: correction, userPrefix: prefix, userSuffix: "")
            print("AutocorrectService: '\(prefix.lowercased())' -> '\(correction)' in \(String(format: "%.3f", duration))ms")
            return correction
        } else {
            print("AutocorrectService: '\(prefix.lowercased())' -> no correction in \(String(format: "%.3f", duration))ms")
            return nil
        }
    }

    private func updateTypeahead(prefix: String, suffix: String) -> ([(String, [InputAction])], String?) {
        let prefixLower = prefix.lowercased()
        let suffixLower = suffix.lowercased()

        let startTime = CFAbsoluteTimeGetCurrent()
        let (matchingWords, exactMatch) = typeaheadService.getCompletions(prefix: prefixLower, suffix: suffixLower)
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds

        if suffix.isEmpty {
            print("TypeaheadService: '\(prefixLower)' -> \(matchingWords.count) completions in \(String(format: "%.3f", duration))ms")
        } else {
            print("TypeaheadService: '\(prefixLower)|\(suffixLower)' -> \(matchingWords.count) completions in \(String(format: "%.3f", duration))ms")
        }

        let suggestions = matchingWords.map { word in
            let displayWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)
            let actions = createInputActions(for: displayWord, prefix: prefix, suffix: suffix, excludeTrailingSpace: false)
            return (displayWord, actions)
        }

        return (suggestions, exactMatch)
    }

    /// Applies smart capitalization rules based on user input patterns
    ///
    /// Rules:
    /// - Users typically type lowercase, so preserve corpus capitalization unless user actively indicates otherwise
    /// - If user input is all lowercase → preserve corpus capitalization
    /// - If user uses capitals → apply their pattern, but only if it results in same or more capitals than corpus
    ///
    /// Examples with regular words:
    /// - "w|d" + "world" → "world" (all lowercase)
    /// - "W|d" + "world" → "World" (title case)
    /// - "Wo|d" + "world" → "World" (title case)
    /// - "W|D" + "world" → "WORLD" (all caps intent)
    /// - "WO|D" + "world" → "WORLD" (all caps)
    /// - "Wo|D" + "world" → "WorlD" (mixed case preserved)
    ///
    /// Examples with proper nouns:
    /// - "sh|" + "Shawn" → "Shawn" (preserve corpus caps)
    /// - "Sh|" + "Shawn" → "Shawn" (matches corpus)
    /// - "SH|" + "Shawn" → "SHAWN" (user wants all caps)
    /// - "SH|" + "should" → "SHOULD" (force all caps on regular word)
    ///
    /// Examples with acronyms:
    /// - "u|" + "USA" → "USA" (preserve corpus caps)
    /// - "U|" + "USA" → "USA" (preserve corpus caps)
    /// - "US|" + "USA" → "USA" (pattern matches corpus)
    /// - "us|" + "USA" → "USA" (preserve corpus caps)
    /// - "Us|" + "USA" → "USA" (preserve corpus caps)
    /// - "uS|" + "USA" → "USA" (preserve corpus caps)
    private func applySmartCapitalization(word: String, userPrefix: String, userSuffix: String) -> String {
        let userPattern = userPrefix + userSuffix

        // If user input is all lowercase, preserve corpus capitalization
        if userPattern.lowercased() == userPattern {
            return word
        }

        // Apply user's capitalization pattern to the full word
        let patternLength = userPattern.count
        let wordLength = word.count

        guard patternLength > 0 && wordLength > 0 else { return word }

        var result = word
        let wordArray = Array(word)
        let patternArray = Array(userPattern)

        // Apply capitalization pattern character by character
        for i in 0..<min(patternLength, wordLength) {
            let patternChar = patternArray[i]
            let wordChar = wordArray[i]

            if patternChar.isUppercase {
                result = String(result.prefix(i)) + String(wordChar).uppercased() + String(result.dropFirst(i + 1))
            } else {
                result = String(result.prefix(i)) + String(wordChar).lowercased() + String(result.dropFirst(i + 1))
            }
        }

        // If pattern is shorter than word, preserve remaining corpus capitalization
        // If user pattern shows "all caps intent" (multiple consecutive capitals), apply to whole word
        if patternLength < wordLength {
            let userCapitals = userPattern.filter { $0.isUppercase }.count
            let isAllCapsIntent = userCapitals == patternLength && userCapitals > 1

            if isAllCapsIntent {
                result = result.uppercased()
            }
            // Otherwise keep remaining characters as they were in corpus
        }

        return result
    }

    private func shouldAddLeadingSpace() -> Bool {
        guard let before = contextBefore, !before.isEmpty else {
            return false
        }

        let lastChar = before.last!

        // Add space after letters or punctuation that typically needs space after it
        return lastChar.isLetter || ".,!?:;".contains(lastChar)
    }

    static func isWordCharacter(in text: String, at index: String.Index) -> Bool {
        let char = text[index]

        if char.isLetter {
            return true
        }

        // Include apostrophe only if it's surrounded by letters on both sides
        if char == "'" {
            let hasLetterBefore = index > text.startIndex && text[text.index(before: index)].isLetter
            let hasLetterAfter = index < text.index(before: text.endIndex) && text[text.index(after: index)].isLetter
            return hasLetterBefore && hasLetterAfter
        }

        return false
    }

    private func extractCurrentWordContext() -> (prefix: String, suffix: String) {
        let prefix: String
        if let before = contextBefore {
            // Find the current word by walking backwards from the end until we hit a non-word character
            var wordStart = before.endIndex
            for index in before.indices.reversed() {
                if Self.isWordCharacter(in: before, at: index) {
                    wordStart = index
                } else {
                    break
                }
            }
            prefix = String(before[wordStart...])
        } else {
            prefix = ""
        }

        let suffix: String
        if let after = contextAfter {
            // Find the suffix by walking forward from the beginning until we hit a non-word character
            var wordEnd = after.startIndex
            for index in after.indices {
                if Self.isWordCharacter(in: after, at: index) {
                    wordEnd = after.index(after: index)
                } else {
                    break
                }
            }
            suffix = String(after[..<wordEnd])
        } else {
            suffix = ""
        }

        return (prefix, suffix)
    }

    private func createInputActions(for word: String, prefix: String, suffix: String, excludeTrailingSpace: Bool) -> [InputAction] {
        var actions: [InputAction] = []
        var addTrailingSpace = !excludeTrailingSpace

        // Find remaining part of word after matching prefix
        var remainingWord = word

        if !prefix.isEmpty {
            let wordChars = Array(word)
            let prefixChars = Array(prefix)
            let minLength = min(wordChars.count, prefixChars.count)
            var matchingPrefixLength = 0

            for i in 0..<minLength {
                if wordChars[i] == prefixChars[i] {
                    matchingPrefixLength += 1
                } else {
                    break
                }
            }

            // Delete the mismatched part of the prefix
            let charsToDelete = prefix.count - matchingPrefixLength
            for _ in 0..<charsToDelete {
                actions.append(.deleteBackward)
            }

            remainingWord = String(word.dropFirst(matchingPrefixLength))
        }

        if !remainingWord.isEmpty && !suffix.isEmpty {
            let insertText = String(remainingWord.dropLast(suffix.count))
            actions.append(.insert(insertText))

            // Move cursor past suffix
            actions.append(.moveCursor(suffix.count))

            // Check if we're at the very end of the document
            if let after = contextAfter, after.dropFirst(suffix.count).isEmpty {
            } else {
                addTrailingSpace = false
            }
        } else if !remainingWord.isEmpty {
            actions.append(.insert(remainingWord))
        } else if !suffix.isEmpty {
            let insertText = String(remainingWord.dropLast(suffix.count))
            actions.append(.insert(insertText))
            addTrailingSpace = false
        } else {
            if shouldAddLeadingSpace() {
                actions.append(.insert(" "))
            }
            actions.append(.insert(remainingWord))
        }

        if addTrailingSpace {
            actions.append(.insert(" "))
            actions.append(.maybePunctuating(true))
        }

        return actions
    }
}

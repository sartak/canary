import Foundation
import SQLite3

enum PredictionAction {
    case insert(String)
    case moveCursor(Int)  // positive = forward, negative = backward
    case maybePunctuating(Bool)
}

class PredictionService {
    private static let maxSuggestions = 20
    private var db: OpaquePointer?

    private var contextBefore: String?
    private var contextAfter: String?
    private var selectedText: String?
    private var cachedSuggestions: [(String, [PredictionAction])]?

    init() {
        openDatabase()
    }

    deinit {
        closeDatabase()
    }

    private func openDatabase() {
        guard let dbPath = Bundle(for: PredictionService.self).path(forResource: "words", ofType: "db") else {
            print("PredictionService: Could not find words.db in keyboard extension bundle")
            return
        }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("PredictionService: Error opening database: \(String(cString: sqlite3_errmsg(db)))")
            closeDatabase()
        }
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func queryWords(prefix: String, suffix: String) -> [String] {
        guard let db = db else { return [] }

        var query: String
        var textBindValues: [String] = []

        if !prefix.isEmpty && !suffix.isEmpty {
            // Both prefix and suffix - use main table with both constraints
            let reversedSuffix = String(suffix.reversed())
            query = """
                SELECT word FROM words
                WHERE word_lower LIKE ? AND word_lower_reversed LIKE ?
                ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)
            """
            textBindValues = ["\(prefix)%", "\(reversedSuffix)%"]
        } else if !prefix.isEmpty {
            // Prefix only - use parameterized LIKE with SQLITE_TRANSIENT
            query = "SELECT word FROM words WHERE word_lower LIKE ? ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
            textBindValues = ["\(prefix)%"]
        } else if !suffix.isEmpty {
            // Suffix only - use suffix table
            let reversedSuffix = String(suffix.reversed())
            query = "SELECT word FROM words_by_suffix WHERE word_lower_reversed LIKE ? ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
            textBindValues = ["\(reversedSuffix)%"]
        } else {
            query = "SELECT word FROM words ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
            textBindValues = []
        }

        var statement: OpaquePointer?
        var results: [String] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // Bind text parameters with SQLITE_TRANSIENT
            for (index, value) in textBindValues.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }

            // Execute query and collect results
            while sqlite3_step(statement) == SQLITE_ROW {
                if let wordPtr = sqlite3_column_text(statement, 0) {
                    let word = String(cString: wordPtr)
                    results.append(word)
                }
            }
        }

        sqlite3_finalize(statement)
        return results
    }

    private func incrementLastChar(_ str: String) -> String {
        guard let lastChar = str.last else { return str }
        let prefix = String(str.dropLast())
        let nextChar = String(UnicodeScalar(lastChar.unicodeScalars.first!.value + 1)!)
        return prefix + nextChar
    }

    func updateContext(before: String?, after: String?, selected: String?) {
        self.contextBefore = before
        self.contextAfter = after
        self.selectedText = selected
        self.cachedSuggestions = nil
    }

    func getSuggestions() -> [(String, [PredictionAction])] {
        if let cached = cachedSuggestions {
            return cached
        }

        let suggestions = makeSuggestions()
        cachedSuggestions = suggestions
        return suggestions
    }

    private func makeSuggestions() -> [(String, [PredictionAction])] {
        let (prefix, suffix) = extractCurrentWordContext()

        let prefixLower = prefix.lowercased()
        let suffixLower = suffix.lowercased()

        let matchingWords = queryWords(prefix: prefixLower, suffix: suffixLower)

        return Array(matchingWords.prefix(Self.maxSuggestions)).map { word in
            let displayWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)

            if !prefix.isEmpty && !suffix.isEmpty {
                // Insert middle part, move cursor past suffix, add space if at end
                let startIndex = displayWord.index(displayWord.startIndex, offsetBy: prefix.count)
                let endIndex = displayWord.index(displayWord.endIndex, offsetBy: -suffix.count)
                let insertText = String(displayWord[startIndex..<endIndex])
                var actions: [PredictionAction] = [.insert(insertText), .moveCursor(suffix.count)]

                // Check if we're at the very end of the document
                if let after = contextAfter, after.dropFirst(suffix.count).isEmpty {
                    actions.append(.insert(" "))
                    actions.append(.maybePunctuating(true))
                }

                return (displayWord, actions)
            } else if !prefix.isEmpty {
                // Remove prefix, add trailing space if no suffix
                let needsTrailingSpace = suffix.isEmpty
                let insertText = String(displayWord.dropFirst(prefix.count)) + (needsTrailingSpace ? " " : "")
                let actions: [PredictionAction] = needsTrailingSpace ? [.insert(insertText), .maybePunctuating(true)] : [.insert(insertText)]
                return (displayWord, actions)
            } else if !suffix.isEmpty {
                // Remove suffix
                let insertText = String(displayWord.dropLast(suffix.count))
                return (displayWord, [.insert(insertText)])
            } else {
                // No prefix/suffix to remove - check spacing
                let needsLeadingSpace = shouldAddLeadingSpace()
                let baseWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)
                let insertText = (needsLeadingSpace ? " " + baseWord : baseWord) + " "
                return (displayWord, [.insert(insertText), .maybePunctuating(true)])
            }
        }
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

    private func extractCurrentWordContext() -> (prefix: String, suffix: String) {
        let prefix: String
        if let before = contextBefore {
            // Find the current word by walking backwards from the end until we hit a non-alpha character
            var wordStart = before.endIndex
            for index in before.indices.reversed() {
                let char = before[index]
                if char.isLetter {
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
            // Find the suffix by walking forward from the beginning until we hit a non-alpha character
            var wordEnd = after.startIndex
            for index in after.indices {
                let char = after[index]
                if char.isLetter {
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
}

import Foundation

enum InputAction {
    case insert(String)
    case moveCursor(Int)  // positive = forward, negative = backward
    case maybePunctuating(Bool)
}

class SuggestionService {
    private var contextBefore: String?
    private var contextAfter: String?
    private var selectedText: String?

    private var typeaheadService: TypeaheadService
    private var typeaheadSuggestions: [(String, [InputAction])]?

    private var typoService: TypoService
    private var typoCurrentWord: String = ""
    private var typoCandidates: [(String, Int, Int)]? = nil // nil = not completed, [] = completed with no results, [results] = completed with results
    private var typoQueue: DispatchQueue
    private var typoTask: DispatchWorkItem?
    private var typoCompletion: ([(String, Int, Int)]?) -> Void = { _ in }

    init?() {
        typoQueue = DispatchQueue(label: "typo-correction", qos: .userInitiated)

        guard let path = Bundle(for: SuggestionService.self).path(forResource: "words", ofType: "db") else {
            return nil
        }

        guard let typoService = TypoService(dbPath: path),
              let typeaheadService = TypeaheadService(dbPath: path) else {
            return nil
        }

        self.typoService = typoService
        self.typeaheadService = typeaheadService
    }

    func updateContext(before: String?, after: String?, selected: String?) {
        self.contextBefore = before
        self.contextAfter = after
        self.selectedText = selected
        self.typeaheadSuggestions = nil

        // Update proactive typo correction
        updateProactiveTypoCorrection()
    }

    private func updateProactiveTypoCorrection() {
        let (prefix, _) = extractCurrentWordContext()
        let newWord = prefix.lowercased()

        // Only start new search if word changed
        if newWord != typoCurrentWord {
            typoCurrentWord = newWord

            // Cancel any existing search
            typoTask?.cancel()

            if newWord.isEmpty {
                typoCandidates = []
                return
            }

            // Mark search as not completed
            typoCandidates = nil

            // Start new background search
            var task: DispatchWorkItem!
            task = DispatchWorkItem { [weak self] in
                guard let self = self else {
                    return
                }

                // Check if search was cancelled by checking if current word changed
                if newWord != self.typoCurrentWord {
                    return
                }

                let startTime = CFAbsoluteTimeGetCurrent()
                let candidates = self.typoService.suggestTypoCorrections(for: newWord, maxDistance: 2, task: task)
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000 // Convert to milliseconds

                if let candidates = candidates {
                    print("TypoService: '\(newWord)' -> \(candidates.count) candidates in \(String(format: "%.3f", duration))ms")
                } else {
                    print("TypoService: '\(newWord)' -> cancelled after \(String(format: "%.3f", duration))ms")
                }

                // Call completion handler immediately (not on main thread to avoid deadlock)
                // But update proactiveCandidates on main thread
                if newWord == self.typoCurrentWord {
                    if let candidates = candidates {
                        DispatchQueue.main.async {
                            self.typoCandidates = candidates
                        }
                        self.typoCompletion(candidates)
                    } else {
                        self.typoCompletion(nil)
                    }
                } else {
                    self.typoCompletion(nil)
                }
            }

            typoTask = task
            typoQueue.async(execute: task)
        }
    }

    func getSuggestions() -> [(String, [InputAction])] {
        if let cached = typeaheadSuggestions {
            return cached
        }

        let suggestions = makeSuggestions()
        typeaheadSuggestions = suggestions
        return suggestions
    }

    private func makeSuggestions() -> [(String, [InputAction])] {
        let (prefix, suffix) = extractCurrentWordContext()

        let prefixLower = prefix.lowercased()
        let suffixLower = suffix.lowercased()

        let startTime = CFAbsoluteTimeGetCurrent()
        let matchingWords = typeaheadService.getCompletions(prefix: prefixLower, suffix: suffixLower)
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds

        if suffix.isEmpty {
            print("TypeaheadService: '\(prefixLower)' -> \(matchingWords.count) completions in \(String(format: "%.3f", duration))ms")
        } else {
            print("TypeaheadService: '\(prefixLower)|\(suffixLower)' -> \(matchingWords.count) completions in \(String(format: "%.3f", duration))ms")
        }

        return matchingWords.map { word in
            let displayWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)

            if !prefix.isEmpty && !suffix.isEmpty {
                // Insert middle part, move cursor past suffix, add space if at end
                let startIndex = displayWord.index(displayWord.startIndex, offsetBy: prefix.count)
                let endIndex = displayWord.index(displayWord.endIndex, offsetBy: -suffix.count)
                let insertText = String(displayWord[startIndex..<endIndex])
                var actions: [InputAction] = [.insert(insertText), .moveCursor(suffix.count)]

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
                let actions: [InputAction] = needsTrailingSpace ? [.insert(insertText), .maybePunctuating(true)] : [.insert(insertText)]
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

    func correctTypo(word: String) -> String? {
        let trimmedWord = word.trimmingCharacters(in: .whitespaces)

        // Skip correction for strings containing invalid characters
        // Only allow words composed entirely of valid word characters
        if !trimmedWord.indices.allSatisfy({ index in
            Self.isWordCharacter(in: trimmedWord, at: index)
        }) {
            return nil
        }

        // Check if word exists in dictionary and apply smart capitalization
        if let canonicalWord = typeaheadService.getCanonicalWord(trimmedWord) {
            let smartCapitalizedWord = applySmartCapitalization(word: canonicalWord, userPrefix: trimmedWord, userSuffix: "")

            if smartCapitalizedWord != trimmedWord {
                return smartCapitalizedWord
            } else {
                return nil
            }
        }

        // Use proactive candidates if available and current
        let candidates: [(String, Int, Int)]?
        var wasCanceled = false

        if trimmedWord.lowercased() == typoCurrentWord {
            if let proactiveResults = typoCandidates {
                // Search already completed proactively - user wait time is essentially 0
                candidates = proactiveResults
            } else if let task = typoTask, !task.isCancelled {
                // Search still running - user must wait for completion
                let semaphore = DispatchSemaphore(value: 0)
                var taskResults: [(String, Int, Int)]?

                typoCompletion = { results in
                    taskResults = results
                    semaphore.signal()
                }

                semaphore.wait()

                candidates = taskResults
                wasCanceled = taskResults == nil
            } else {
                // No search running - no correction
                candidates = []
            }
        } else {
            // Word doesn't match current search - no correction
            candidates = []
        }

        guard let candidates = candidates, !candidates.isEmpty, !wasCanceled else {
            return nil
        }

        // Find best candidate: lowest distance, then lowest frequency_rank (higher frequency)
        let bestCandidate = candidates.min { a, b in
            a.1 != b.1 ? a.1 < b.1 : a.2 < b.2
        }

        return bestCandidate.map {
            applySmartCapitalization(word: $0.0, userPrefix: trimmedWord, userSuffix: "")
        }
    }
}

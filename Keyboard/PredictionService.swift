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
    private var dbPath: String?

    // Cache most common words (no prefix/suffix) since they're queried frequently
    private static var commonWords: [String]?

    private var contextBefore: String?
    private var contextAfter: String?
    private var selectedText: String?
    private var cachedSuggestions: [(String, [PredictionAction])]?

    // Proactive typo correction state
    private var currentSearchWord: String = ""
    private var proactiveCandidates: [(String, Int, Int)]? = nil // nil = not completed, [] = completed with no results, [results] = completed with results
    private var proactiveSearchTime: Double = 0 // Time spent in database for proactive search
    private var backgroundQueue: DispatchQueue
    private var backgroundDB: OpaquePointer?
    private var searchTask: DispatchWorkItem?
    private var currentSearchCompletion: ([(String, Int, Int)]?, Double) -> Void = { _, _ in }

    init() {
        backgroundQueue = DispatchQueue(label: "typo-correction", qos: .userInitiated)
        openDatabase()
        openBackgroundDatabase()
    }

    deinit {
        closeDatabase()
        closeBackgroundDatabase()
    }

    private func openDatabase() {
        guard let path = Bundle(for: PredictionService.self).path(forResource: "words", ofType: "db") else {
            print("PredictionService: Could not find words.db in keyboard extension bundle")
            return
        }

        dbPath = path

        if sqlite3_open(path, &db) != SQLITE_OK {
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

    private func openBackgroundDatabase() {
        guard let dbPath = dbPath else { return }

        if sqlite3_open(dbPath, &backgroundDB) != SQLITE_OK {
            print("PredictionService: Error opening background database: \(String(cString: sqlite3_errmsg(backgroundDB)))")
            closeBackgroundDatabase()
        }
    }

    private func closeBackgroundDatabase() {
        if backgroundDB != nil {
            sqlite3_close(backgroundDB)
            backgroundDB = nil
        }
    }

    private func queryWords(prefix: String, suffix: String) -> [String] {
        guard let db = db else { return [] }

        // Cache most common words (no prefix/suffix) since they're queried frequently
        if prefix.isEmpty && suffix.isEmpty {
            if let cached = Self.commonWords {
                return cached
            }
        }

        var query: String
        var textBindValues: [String] = []

        if !prefix.isEmpty && !suffix.isEmpty {
            // Both prefix and suffix - use main table with both constraints
            let reversedSuffix = String(suffix.reversed())
            query = """
                SELECT word FROM words
                WHERE word_lower LIKE ? AND word_lower_reversed LIKE ? AND hidden = 0
                ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)
            """
            textBindValues = ["\(prefix)%", "\(reversedSuffix)%"]
        } else if !prefix.isEmpty {
            // Prefix only - use parameterized LIKE with SQLITE_TRANSIENT
            query = "SELECT word FROM words WHERE word_lower LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
            textBindValues = ["\(prefix)%"]
        } else if !suffix.isEmpty {
            // Suffix only - use suffix table
            let reversedSuffix = String(suffix.reversed())
            query = "SELECT word FROM words_by_suffix WHERE word_lower_reversed LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
            textBindValues = ["\(reversedSuffix)%"]
        } else {
            query = "SELECT word FROM words WHERE hidden = 0 ORDER BY frequency_rank LIMIT \(Self.maxSuggestions)"
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

        // Cache common words for future use
        if prefix.isEmpty && suffix.isEmpty {
            Self.commonWords = results
        }

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

        // Update proactive typo correction
        updateProactiveTypoCorrection()
    }

    private func updateProactiveTypoCorrection() {
        let (prefix, _) = extractCurrentWordContext()
        let newWord = prefix.lowercased()

        // Only start new search if word changed
        if newWord != currentSearchWord {
            currentSearchWord = newWord

            // Cancel any existing search
            searchTask?.cancel()

            // Interrupt any ongoing SQLite queries on background database
            if let backgroundDB = backgroundDB {
                sqlite3_interrupt(backgroundDB)
            }

            if newWord.isEmpty {
                proactiveCandidates = []
                return
            }

            // Mark search as not completed
            proactiveCandidates = nil


            // Start new background search
            var task: DispatchWorkItem!
            task = DispatchWorkItem { [weak self] in
                guard let self = self, let backgroundDB = self.backgroundDB else {
                    return
                }

                // Check if search was cancelled by checking if current word changed
                if newWord != self.currentSearchWord {
                    return
                }

                let searchStart = CFAbsoluteTimeGetCurrent()
                let candidates = self.queryBKTreeWithDB(db: backgroundDB, word: newWord, maxDistance: 2, task: task)
                let searchTime = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000

                // Call completion handler immediately (not on main thread to avoid deadlock)
                // But update proactiveCandidates on main thread
                if newWord == self.currentSearchWord {
                    if let candidates = candidates {
                        DispatchQueue.main.async {
                            self.proactiveCandidates = candidates
                            self.proactiveSearchTime = searchTime
                        }
                        self.currentSearchCompletion(candidates, searchTime)
                    } else {
                        self.currentSearchCompletion(nil, searchTime)
                    }
                } else {
                    self.currentSearchCompletion(nil, searchTime)
                }
            }

            searchTask = task
            backgroundQueue.async(execute: task)
        }
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

    private func isWordCharacter(in text: String, at index: String.Index) -> Bool {
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
                if isWordCharacter(in: before, at: index) {
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
                if isWordCharacter(in: after, at: index) {
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

    // MARK: - Typo Correction

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previousRow = Array(0...b.count)

        for (i, aChar) in a.enumerated() {
            var currentRow = [i + 1]

            for (j, bChar) in b.enumerated() {
                let insertions = previousRow[j + 1] + 1
                let deletions = currentRow[j] + 1
                let substitutions = previousRow[j] + (aChar == bChar ? 0 : 1)
                currentRow.append(min(insertions, deletions, substitutions))
            }

            previousRow = currentRow
        }

        return previousRow.last!
    }

    private func getCanonicalWord(_ word: String) -> String? {
        guard let db = db else { return nil }

        let query = "SELECT word FROM words WHERE word_lower = ? LIMIT 1"
        var statement: OpaquePointer?
        var canonicalWord: String?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, word.lowercased(), -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            if sqlite3_step(statement) == SQLITE_ROW {
                if let wordPtr = sqlite3_column_text(statement, 0) {
                    canonicalWord = String(cString: wordPtr)
                }
            }
        }

        sqlite3_finalize(statement)
        return canonicalWord
    }

    private func queryBKTree(word: String, maxDistance: Int) -> [(String, Int, Int)]? {
        guard let db = db else { return [] }
        return queryBKTreeWithDB(db: db, word: word, maxDistance: maxDistance, task: nil)
    }

    private func queryBKTreeWithDB(db: OpaquePointer, word: String, maxDistance: Int, task: DispatchWorkItem?) -> [(String, Int, Int)]? {
        var candidates: [(String, Int, Int)] = [] // (word, distance, frequency_rank)
        var queue: [Int] = [1] // Just node_ids for simpler queue
        var visited: Set<Int> = [] // Avoid revisiting nodes
        var nodesExplored = 0

        while !queue.isEmpty {
            // Check if search was cancelled
            if task?.isCancelled == true {
                return nil
            }

            let nodeId = queue.removeFirst()

            if visited.contains(nodeId) {
                continue
            }
            visited.insert(nodeId)
            nodesExplored += 1

            // Get word for current node
            var nodeStatement: OpaquePointer?
            let nodeQuery = "SELECT word, frequency_rank, hidden FROM bk_nodes WHERE node_id = ?"

            if sqlite3_prepare_v2(db, nodeQuery, -1, &nodeStatement, nil) == SQLITE_OK {
                sqlite3_bind_int(nodeStatement, 1, Int32(nodeId))

                let stepResult = sqlite3_step(nodeStatement)
                if stepResult == SQLITE_ROW {
                    let nodeWordPtr = sqlite3_column_text(nodeStatement, 0)
                    let nodeWord = String(cString: nodeWordPtr!)
                    let frequencyRank = Int(sqlite3_column_int(nodeStatement, 1))
                    let isHidden = Int(sqlite3_column_int(nodeStatement, 2))

                    let distance = levenshteinDistance(word, nodeWord)
                    if distance <= maxDistance && isHidden == 0 {
                        candidates.append((nodeWord, distance, frequencyRank))
                    }

                    // Add children to queue if they could contain valid candidates
                    let minChildDistance = max(0, distance - maxDistance)
                    let maxChildDistance = distance + maxDistance

                    var edgeStatement: OpaquePointer?
                    let edgeQuery = "SELECT child_id FROM bk_edges WHERE parent_id = ? AND distance >= ? AND distance <= ?"

                    if sqlite3_prepare_v2(db, edgeQuery, -1, &edgeStatement, nil) == SQLITE_OK {
                        sqlite3_bind_int(edgeStatement, 1, Int32(nodeId))
                        sqlite3_bind_int(edgeStatement, 2, Int32(minChildDistance))
                        sqlite3_bind_int(edgeStatement, 3, Int32(maxChildDistance))

                        while true {
                            let edgeStepResult = sqlite3_step(edgeStatement)
                            if edgeStepResult == SQLITE_ROW {
                                let childId = Int(sqlite3_column_int(edgeStatement, 0))
                                if !visited.contains(childId) {
                                    queue.append(childId)
                                }
                            } else if edgeStepResult == SQLITE_INTERRUPT {
                                sqlite3_finalize(edgeStatement)
                                sqlite3_finalize(nodeStatement)
                                return nil
                            } else {
                                break
                            }
                        }
                    }

                    sqlite3_finalize(edgeStatement)
                } else if stepResult == SQLITE_INTERRUPT {
                    sqlite3_finalize(nodeStatement)
                    return nil
                }
            }

            sqlite3_finalize(nodeStatement)
        }

        return candidates
    }

    func correctTypo(word: String) -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let trimmedWord = word.trimmingCharacters(in: .whitespaces)

        // Skip correction for strings containing numbers or special characters
        // Typo correction is only for pure alphabetic words
        if !trimmedWord.allSatisfy({ $0.isLetter }) {
            return nil
        }

        // Check if word exists in dictionary and apply smart capitalization
        let dictionaryCheckStart = CFAbsoluteTimeGetCurrent()
        if let canonicalWord = getCanonicalWord(trimmedWord) {
            let dictionaryTime = (CFAbsoluteTimeGetCurrent() - dictionaryCheckStart) * 1000
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("TypoCorrection: '\(trimmedWord)' -> found in dictionary, db_time: \(String(format: "%.3f", dictionaryTime))ms, user_wait: \(String(format: "%.3f", totalTime))ms")

            // Apply smart capitalization based on user input
            let smartCapitalizedWord = applySmartCapitalization(word: canonicalWord, userPrefix: trimmedWord, userSuffix: "")

            if smartCapitalizedWord != trimmedWord {
                return smartCapitalizedWord
            } else {
                return nil
            }
        }

        // Use proactive candidates if available and current
        let candidates: [(String, Int, Int)]?
        var dbTime: Double = 0
        var wasCanceled = false

        if trimmedWord.lowercased() == currentSearchWord {
            if let proactiveResults = proactiveCandidates {
                // Search already completed proactively - user wait time is essentially 0
                candidates = proactiveResults
                dbTime = proactiveSearchTime
            } else if let task = searchTask, !task.isCancelled {
                // Search still running - user must wait for completion
                let semaphore = DispatchSemaphore(value: 0)
                var taskResults: [(String, Int, Int)]?
                var totalDbTimeFromTask: Double = 0

                currentSearchCompletion = { results, dbTimeFromTask in
                    taskResults = results
                    totalDbTimeFromTask = dbTimeFromTask
                    semaphore.signal()
                }

                semaphore.wait()

                if taskResults == nil {
                    wasCanceled = true
                    candidates = nil
                    dbTime = totalDbTimeFromTask // Actual db time even if canceled
                } else {
                    candidates = taskResults!
                    // Use the actual database time from the background task
                    dbTime = totalDbTimeFromTask
                }
            } else {
                // No search running - no correction
                candidates = []
            }
        } else {
            // Word doesn't match current search - no correction
            candidates = []
        }

        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Log the result
        if wasCanceled {
            print("TypoCorrection: '\(trimmedWord)' -> search canceled, user_wait: \(String(format: "%.3f", totalTime))ms")
            return nil
        }

        guard let candidates = candidates else {
            print("TypoCorrection: '\(trimmedWord)' -> search canceled, user_wait: \(String(format: "%.3f", totalTime))ms")
            return nil
        }

        let candidateCount = candidates.count

        // Distinguish between proactive (async) vs synchronous completion
        if trimmedWord.lowercased() == currentSearchWord && proactiveCandidates != nil {
            // Proactive search completed before user needed it
            print("TypoCorrection: '\(trimmedWord)' -> \(candidateCount) candidates (async), db_time: \(String(format: "%.3f", dbTime))ms, user_wait: \(String(format: "%.3f", totalTime))ms")
        } else {
            // Had to wait for search to complete
            print("TypoCorrection: '\(trimmedWord)' -> \(candidateCount) candidates (sync), db_time: \(String(format: "%.3f", dbTime))ms, user_wait: \(String(format: "%.3f", totalTime))ms")
        }

        if candidates.isEmpty {
            return nil
        }

        // Find best candidate: lowest distance, then lowest frequency_rank (higher frequency)
        let bestCandidate = candidates.min { a, b in
            if a.1 != b.1 {
                return a.1 < b.1 // Lower distance is better
            }
            return a.2 < b.2 // Lower frequency_rank is better (higher frequency)
        }

        // Apply smart capitalization to the correction
        if let candidateWord = bestCandidate?.0 {
            return applySmartCapitalization(word: candidateWord, userPrefix: trimmedWord, userSuffix: "")
        }

        return nil
    }
}

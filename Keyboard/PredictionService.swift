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
    private var proactiveCandidates: [(String, Int, Int)] = [] // (word, distance, frequency_rank)
    private var backgroundQueue: DispatchQueue
    private var backgroundDB: OpaquePointer?
    private var searchTask: DispatchWorkItem?

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

            if newWord.isEmpty {
                proactiveCandidates = []
                return
            }

            print("ProactiveTypo: Starting background search for '\(newWord)'")

            // Start new background search
            let task = DispatchWorkItem { [weak self] in
                guard let self = self, let backgroundDB = self.backgroundDB else { return }

                let startTime = CFAbsoluteTimeGetCurrent()

                // Check if search was cancelled by checking if current word changed
                if newWord != self.currentSearchWord {
                    print("ProactiveTypo: '\(newWord)' search cancelled before query")
                    return
                }

                let candidates = self.queryBKTreeWithDB(db: backgroundDB, word: newWord, maxDistance: 2)
                let queryTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

                // Update results on main thread
                DispatchQueue.main.async {
                    // Only update if this search is still current (not cancelled)
                    if newWord == self.currentSearchWord {
                        self.proactiveCandidates = candidates
                        print("ProactiveTypo: '\(newWord)' completed, found \(candidates.count) candidates in \(String(format: "%.1f", queryTime))ms")
                    } else {
                        print("ProactiveTypo: '\(newWord)' search was cancelled or obsolete")
                    }
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

    private func wordExists(_ word: String) -> Bool {
        guard let db = db else { return false }

        let query = "SELECT 1 FROM words WHERE word_lower = ? LIMIT 1"
        var statement: OpaquePointer?
        var exists = false

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, word.lowercased(), -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            if sqlite3_step(statement) == SQLITE_ROW {
                exists = true
            }
        }

        sqlite3_finalize(statement)
        return exists
    }

    private func queryBKTree(word: String, maxDistance: Int) -> [(String, Int, Int)] {
        guard let db = db else { return [] }
        return queryBKTreeWithDB(db: db, word: word, maxDistance: maxDistance)
    }

    private func queryBKTreeWithDB(db: OpaquePointer, word: String, maxDistance: Int) -> [(String, Int, Int)] {

        var candidates: [(String, Int, Int)] = [] // (word, distance, frequency_rank)
        var queue: [Int] = [1] // Just node_ids for simpler queue
        var visited: Set<Int> = [] // Avoid revisiting nodes
        var nodesExplored = 0

        while !queue.isEmpty && nodesExplored < 2000 { // Limit exploration to prevent runaway queries
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

                if sqlite3_step(nodeStatement) == SQLITE_ROW {
                    let nodeWordPtr = sqlite3_column_text(nodeStatement, 0)
                    let nodeWord = String(cString: nodeWordPtr!)
                    let frequencyRank = Int(sqlite3_column_int(nodeStatement, 1))
                    let isHidden = Int(sqlite3_column_int(nodeStatement, 2))

                    let distance = levenshteinDistance(word, nodeWord)

                    if distance <= maxDistance && isHidden == 0 {
                        candidates.append((nodeWord, distance, frequencyRank))
                    }

                    // Early exit only if we have multiple distance-1 candidates
                    let distance1Count = candidates.filter { $0.1 == 1 }.count
                    if distance1Count >= 5 {
                        sqlite3_finalize(nodeStatement)
                        break
                    }

                    // Add children to queue if they could contain valid candidates
                    let minChildDistance = max(1, distance - maxDistance)
                    let maxChildDistance = distance + maxDistance

                    var edgeStatement: OpaquePointer?
                    let edgeQuery = "SELECT child_id FROM bk_edges WHERE parent_id = ? AND distance >= ? AND distance <= ?"

                    if sqlite3_prepare_v2(db, edgeQuery, -1, &edgeStatement, nil) == SQLITE_OK {
                        sqlite3_bind_int(edgeStatement, 1, Int32(nodeId))
                        sqlite3_bind_int(edgeStatement, 2, Int32(minChildDistance))
                        sqlite3_bind_int(edgeStatement, 3, Int32(maxChildDistance))

                        while sqlite3_step(edgeStatement) == SQLITE_ROW {
                            let childId = Int(sqlite3_column_int(edgeStatement, 0))
                            if !visited.contains(childId) {
                                queue.append(childId)
                            }
                        }
                    }

                    sqlite3_finalize(edgeStatement)
                }
            }

            sqlite3_finalize(nodeStatement)
        }

        return candidates
    }


    func correctTypo(word: String) -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let trimmedWord = word.trimmingCharacters(in: .whitespaces)

        // Return nil if word exists in dictionary
        let existsCheckStart = CFAbsoluteTimeGetCurrent()
        if wordExists(trimmedWord) {
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("TypoCorrection: '\(trimmedWord)' exists in dictionary, total: \(String(format: "%.2f", totalTime))ms")
            return nil
        }
        let existsCheckTime = (CFAbsoluteTimeGetCurrent() - existsCheckStart) * 1000

        // Use pre-computed proactive candidates if available and current
        var candidates: [(String, Int, Int)]
        var queryTime: Double

        if trimmedWord.lowercased() == currentSearchWord {
            if !proactiveCandidates.isEmpty {
                // Use pre-computed candidates
                queryTime = 0.0
                candidates = proactiveCandidates
                print("TypoCorrection: Using proactive candidates for '\(trimmedWord)'")
            } else if let task = searchTask, !task.isCancelled {
                // Wait for the ongoing proactive search to complete
                let queryStart = CFAbsoluteTimeGetCurrent()
                print("TypoCorrection: Waiting for proactive search to complete for '\(trimmedWord)'")

                // Wait for the task to complete
                task.wait()

                queryTime = (CFAbsoluteTimeGetCurrent() - queryStart) * 1000
                candidates = proactiveCandidates
                print("TypoCorrection: Proactive search completed, using results for '\(trimmedWord)'")
            } else {
                // No proactive search running, do synchronous search
                let queryStart = CFAbsoluteTimeGetCurrent()
                candidates = queryBKTree(word: trimmedWord, maxDistance: 2)
                queryTime = (CFAbsoluteTimeGetCurrent() - queryStart) * 1000
                print("TypoCorrection: No proactive search, using synchronous search for '\(trimmedWord)'")
            }
        } else {
            // Different word, do synchronous search
            let queryStart = CFAbsoluteTimeGetCurrent()
            candidates = queryBKTree(word: trimmedWord, maxDistance: 2)
            queryTime = (CFAbsoluteTimeGetCurrent() - queryStart) * 1000
            print("TypoCorrection: Different word, using synchronous search for '\(trimmedWord)' (was searching for '\(currentSearchWord)')")
        }

        // Return nil if no candidates found
        if candidates.isEmpty {
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("TypoCorrection: '\(trimmedWord)' no candidates found, exists: \(String(format: "%.2f", existsCheckTime))ms, query: \(String(format: "%.2f", queryTime))ms, total: \(String(format: "%.2f", totalTime))ms")
            return nil
        }

        // Find best candidate: lowest distance, then lowest frequency_rank (higher frequency)
        let bestCandidate = candidates.min { a, b in
            if a.1 != b.1 {
                return a.1 < b.1 // Lower distance is better
            }
            return a.2 < b.2 // Lower frequency_rank is better (higher frequency)
        }

        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Debug: show top candidates by distance and frequency
        let sortedCandidates = candidates.sorted { a, b in
            if a.1 != b.1 {
                return a.1 < b.1 // Lower distance first
            }
            return a.2 < b.2 // Lower frequency_rank (higher frequency) first
        }
        let topCandidates = Array(sortedCandidates.prefix(10))
        let candidateStr = topCandidates.map { "'\($0.0)'(d\($0.1),f\($0.2))" }.joined(separator: ", ")

        print("TypoCorrection: '\(trimmedWord)' → '\(bestCandidate?.0 ?? "nil")' (\(candidates.count) candidates: \(candidateStr)), exists: \(String(format: "%.2f", existsCheckTime))ms, query: \(String(format: "%.2f", queryTime))ms, total: \(String(format: "%.2f", totalTime))ms")

        return bestCandidate?.0
    }
}

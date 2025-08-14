import Foundation
import SQLite3

class TypeaheadService {
    private let db: OpaquePointer
    private static var commonWords: [String]?
    private let maxSuggestions: Int

    // Cached prepared statements
    private let prefixSuffixStatement: OpaquePointer
    private let prefixOnlyStatement: OpaquePointer
    private let suffixOnlyStatement: OpaquePointer
    private let commonWordsStatement: OpaquePointer

    init?(db: OpaquePointer, maxSuggestions: Int = 20) {
        self.maxSuggestions = maxSuggestions
        self.db = db

        // Prepare statements - if any fail, cleanup and return nil
        var prefixSuffixStmt: OpaquePointer?
        var prefixOnlyStmt: OpaquePointer?
        var suffixOnlyStmt: OpaquePointer?
        var commonWordsStmt: OpaquePointer?

        let prefixSuffixQuery = """
            SELECT word FROM words
            WHERE word_lower LIKE ? AND word_lower_reversed LIKE ? AND hidden = 0
            ORDER BY frequency_rank LIMIT \(maxSuggestions)
        """

        let prefixOnlyQuery = "SELECT word FROM prefixes WHERE prefix_lower = ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        let suffixOnlyQuery = "SELECT word FROM words_by_suffix WHERE word_lower_reversed LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        let commonWordsQuery = "SELECT word FROM words WHERE hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        guard sqlite3_prepare_v2(db, prefixSuffixQuery, -1, &prefixSuffixStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, prefixOnlyQuery, -1, &prefixOnlyStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, suffixOnlyQuery, -1, &suffixOnlyStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, commonWordsQuery, -1, &commonWordsStmt, nil) == SQLITE_OK,
              let prefixSuffixStatement = prefixSuffixStmt,
              let prefixOnlyStatement = prefixOnlyStmt,
              let suffixOnlyStatement = suffixOnlyStmt,
              let commonWordsStatement = commonWordsStmt else {

            // Cleanup on failure
            sqlite3_finalize(prefixSuffixStmt)
            sqlite3_finalize(prefixOnlyStmt)
            sqlite3_finalize(suffixOnlyStmt)
            sqlite3_finalize(commonWordsStmt)
            sqlite3_close(db)
            return nil
        }

        self.prefixSuffixStatement = prefixSuffixStatement
        self.prefixOnlyStatement = prefixOnlyStatement
        self.suffixOnlyStatement = suffixOnlyStatement
        self.commonWordsStatement = commonWordsStatement
    }

    deinit {
        sqlite3_finalize(prefixSuffixStatement)
        sqlite3_finalize(prefixOnlyStatement)
        sqlite3_finalize(suffixOnlyStatement)
        sqlite3_finalize(commonWordsStatement)
    }

    func getCompletions(prefix: String, suffix: String) -> (completions: [String], exactMatch: String?) {
        // Cache most common words (no prefix/suffix) since they're queried frequently
        if prefix.isEmpty && suffix.isEmpty {
            if let cached = Self.commonWords {
                return (cached, nil)
            }
        }

        let statement: OpaquePointer
        if !prefix.isEmpty && !suffix.isEmpty {
            statement = prefixSuffixStatement
            let reversedSuffix = String(suffix.reversed())
            sqlite3_bind_text(statement, 1, "\(prefix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, "\(reversedSuffix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if !prefix.isEmpty {
            statement = prefixOnlyStatement
            sqlite3_bind_text(statement, 1, prefix.lowercased(), -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if !suffix.isEmpty {
            statement = suffixOnlyStatement
            let reversedSuffix = String(suffix.reversed())
            sqlite3_bind_text(statement, 1, "\(reversedSuffix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            statement = commonWordsStatement
        }

        var results: [String] = []
        var exactMatch: String?

        // Target word to check for exact match
        let targetWord = !prefix.isEmpty ? (prefix + suffix).lowercased() : nil

        while sqlite3_step(statement) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(statement, 0) {
                let word = String(cString: wordPtr)
                results.append(word)

                // Check if this word is an exact match for our target
                if let target = targetWord, exactMatch == nil && word.lowercased() == target {
                    exactMatch = word
                }
            }
        }

        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)

        // Cache common words for future use
        if prefix.isEmpty && suffix.isEmpty {
            Self.commonWords = results
        }

        return (results, exactMatch)
    }
}

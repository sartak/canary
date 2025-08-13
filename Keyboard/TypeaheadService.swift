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
    private let canonicalWordStatement: OpaquePointer

    init?(dbPath: String, maxSuggestions: Int = 20) {
        self.maxSuggestions = maxSuggestions

        var dbTemp: OpaquePointer?
        if sqlite3_open(dbPath, &dbTemp) != SQLITE_OK {
            print("TypeaheadService: Error opening database: \(String(cString: sqlite3_errmsg(dbTemp)))")
            if dbTemp != nil {
                sqlite3_close(dbTemp)
            }
            return nil
        }

        guard let db = dbTemp else {
            return nil
        }
        self.db = db

        // Prepare statements - if any fail, cleanup and return nil
        var prefixSuffixStmt: OpaquePointer?
        var prefixOnlyStmt: OpaquePointer?
        var suffixOnlyStmt: OpaquePointer?
        var commonWordsStmt: OpaquePointer?
        var canonicalWordStmt: OpaquePointer?

        let prefixSuffixQuery = """
            SELECT word FROM words
            WHERE word_lower LIKE ? AND word_lower_reversed LIKE ? AND hidden = 0
            ORDER BY frequency_rank LIMIT \(maxSuggestions)
        """

        let prefixOnlyQuery = "SELECT word FROM words WHERE word_lower LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        let suffixOnlyQuery = "SELECT word FROM words_by_suffix WHERE word_lower_reversed LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        let commonWordsQuery = "SELECT word FROM words WHERE hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"

        let canonicalWordQuery = "SELECT word FROM words WHERE word_lower = ? LIMIT 1"

        guard sqlite3_prepare_v2(db, prefixSuffixQuery, -1, &prefixSuffixStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, prefixOnlyQuery, -1, &prefixOnlyStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, suffixOnlyQuery, -1, &suffixOnlyStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, commonWordsQuery, -1, &commonWordsStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, canonicalWordQuery, -1, &canonicalWordStmt, nil) == SQLITE_OK,
              let prefixSuffixStatement = prefixSuffixStmt,
              let prefixOnlyStatement = prefixOnlyStmt,
              let suffixOnlyStatement = suffixOnlyStmt,
              let commonWordsStatement = commonWordsStmt,
              let canonicalWordStatement = canonicalWordStmt else {

            // Cleanup on failure
            sqlite3_finalize(prefixSuffixStmt)
            sqlite3_finalize(prefixOnlyStmt)
            sqlite3_finalize(suffixOnlyStmt)
            sqlite3_finalize(commonWordsStmt)
            sqlite3_finalize(canonicalWordStmt)
            sqlite3_close(db)
            return nil
        }

        self.prefixSuffixStatement = prefixSuffixStatement
        self.prefixOnlyStatement = prefixOnlyStatement
        self.suffixOnlyStatement = suffixOnlyStatement
        self.commonWordsStatement = commonWordsStatement
        self.canonicalWordStatement = canonicalWordStatement
    }

    deinit {
        sqlite3_finalize(prefixSuffixStatement)
        sqlite3_finalize(prefixOnlyStatement)
        sqlite3_finalize(suffixOnlyStatement)
        sqlite3_finalize(commonWordsStatement)
        sqlite3_finalize(canonicalWordStatement)
        sqlite3_close(db)
    }

    func getCompletions(prefix: String, suffix: String) -> [String] {

        // Cache most common words (no prefix/suffix) since they're queried frequently
        if prefix.isEmpty && suffix.isEmpty {
            if let cached = Self.commonWords {
                return cached
            }
        }

        var statement: OpaquePointer?
        var results: [String] = []

        if !prefix.isEmpty && !suffix.isEmpty {
            // Both prefix and suffix
            statement = prefixSuffixStatement
            let reversedSuffix = String(suffix.reversed())
            sqlite3_bind_text(statement, 1, "\(prefix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, "\(reversedSuffix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if !prefix.isEmpty {
            // Prefix only
            statement = prefixOnlyStatement
            sqlite3_bind_text(statement, 1, "\(prefix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if !suffix.isEmpty {
            // Suffix only
            statement = suffixOnlyStatement
            let reversedSuffix = String(suffix.reversed())
            sqlite3_bind_text(statement, 1, "\(reversedSuffix)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            // Common words
            statement = commonWordsStatement
        }

        if let statement = statement {
            // Execute query and collect results
            while sqlite3_step(statement) == SQLITE_ROW {
                if let wordPtr = sqlite3_column_text(statement, 0) {
                    let word = String(cString: wordPtr)
                    results.append(word)
                }
            }

            // Reset statement for next use
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }

        // Cache common words for future use
        if prefix.isEmpty && suffix.isEmpty {
            Self.commonWords = results
        }

        return results
    }

    func getCanonicalWord(_ word: String) -> String? {
        var canonicalWord: String?
        sqlite3_bind_text(canonicalWordStatement, 1, word.lowercased(), -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if sqlite3_step(canonicalWordStatement) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(canonicalWordStatement, 0) {
                canonicalWord = String(cString: wordPtr)
            }
        }

        // Reset statement for next use
        sqlite3_reset(canonicalWordStatement)
        sqlite3_clear_bindings(canonicalWordStatement)

        return canonicalWord
    }
}

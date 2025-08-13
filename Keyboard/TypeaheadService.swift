import Foundation
import SQLite3

class TypeaheadService {
    private var db: OpaquePointer?
    private static var commonWords: [String]?
    private let maxSuggestions: Int

    init?(dbPath: String, maxSuggestions: Int = 20) {
        self.maxSuggestions = maxSuggestions

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("TypeaheadService: Error opening database: \(String(cString: sqlite3_errmsg(db)))")
            close()
            return nil
        }
    }

    deinit {
        close()
    }

    private func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    func getCompletions(prefix: String, suffix: String) -> [String] {
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
                ORDER BY frequency_rank LIMIT \(maxSuggestions)
            """
            textBindValues = ["\(prefix)%", "\(reversedSuffix)%"]
        } else if !prefix.isEmpty {
            // Prefix only - use parameterized LIKE with SQLITE_TRANSIENT
            query = "SELECT word FROM words WHERE word_lower LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"
            textBindValues = ["\(prefix)%"]
        } else if !suffix.isEmpty {
            // Suffix only - use suffix table
            let reversedSuffix = String(suffix.reversed())
            query = "SELECT word FROM words_by_suffix WHERE word_lower_reversed LIKE ? AND hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"
            textBindValues = ["\(reversedSuffix)%"]
        } else {
            query = "SELECT word FROM words WHERE hidden = 0 ORDER BY frequency_rank LIMIT \(maxSuggestions)"
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

    func getCanonicalWord(_ word: String) -> String? {
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
}

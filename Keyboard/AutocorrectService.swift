import Foundation
import SQLite3
import simd

class AutocorrectService {
    private let db: OpaquePointer

    // Cache for batch queries by placeholder count
    private var batchQueryCache: [Int: OpaquePointer] = [:]

    init(db: OpaquePointer) {
        self.db = db
    }

    deinit {
        // Clean up cached batch query statements
        for (_, statement) in batchQueryCache {
            sqlite3_finalize(statement)
        }
    }

    func cancel() {
        sqlite3_interrupt(db)
    }

    func findBestCorrection(for word: String, maxDistance: Int, task: DispatchWorkItem? = nil) -> String? {
        for distance in 1...maxDistance {
            if let result = querySymSpell(word: word, exactDistance: distance, task: task) {
                return result
            }
        }
        return nil
    }

    private func querySymSpell(word: String, exactDistance: Int, task: DispatchWorkItem?) -> String? {
        if task?.isCancelled == true {
            return nil
        }

        let deletes = generateDeletes(word: word, maxEditDistance: exactDistance)
        let deleteHashes = deletes.map { hashString($0) }

        let hashCount = deleteHashes.count
        let batchStatement: OpaquePointer

        if let cachedStatement = batchQueryCache[hashCount] {
            batchStatement = cachedStatement
        } else {
            let placeholders = Array(repeating: "?", count: hashCount).joined(separator: ",")
            let batchQuery = """
                SELECT word, frequency_rank
                FROM symspell_deletes
                WHERE delete_hash IN (\(placeholders))
                ORDER BY frequency_rank ASC
            """

            var newStatement: OpaquePointer?
            guard sqlite3_prepare_v2(db, batchQuery, -1, &newStatement, nil) == SQLITE_OK,
                  let statement = newStatement else {
                return nil
            }

            batchQueryCache[hashCount] = statement
            batchStatement = statement
        }

        for (index, deleteHash) in deleteHashes.enumerated() {
            sqlite3_bind_int64(batchStatement, Int32(index + 1), deleteHash)
        }

        while true {
            let stepResult = sqlite3_step(batchStatement)
            if stepResult == SQLITE_ROW {
                let candidateWordPtr = sqlite3_column_text(batchStatement, 0)
                let candidateWord = String(cString: candidateWordPtr!)

                let distance = levenshteinDistance(word, candidateWord, maxDistance: exactDistance)
                if distance == exactDistance {
                    sqlite3_reset(batchStatement)
                    sqlite3_clear_bindings(batchStatement)
                    return candidateWord
                }
            } else {
                break
            }
        }

        sqlite3_reset(batchStatement)
        sqlite3_clear_bindings(batchStatement)
        return nil
    }

    private func generateDeletes(word: String, maxEditDistance: Int) -> Set<String> {
        var deletes: Set<String> = []

        func generateDeletesRecursive(chars: [Character], editDistance: Int) {
            let word = String(chars)
            deletes.insert(word)

            if editDistance < maxEditDistance {
                if chars.count > 1 {
                    for i in 0..<chars.count {
                        // Create new array with character at index i removed
                        var deletedChars = chars
                        deletedChars.remove(at: i)

                        let deletedWord = String(deletedChars)
                        if !deletes.contains(deletedWord) {
                            generateDeletesRecursive(chars: deletedChars, editDistance: editDistance + 1)
                        }
                    }
                }
            }
        }

        generateDeletesRecursive(chars: Array(word), editDistance: 0)
        return deletes
    }

    private func hashString(_ string: String) -> Int64 {
        // Simple hash function consistent with Python build script
        var hashValue: Int64 = 0
        for char in string.unicodeScalars {
            hashValue = (hashValue &* 31 &+ Int64(char.value)) & 0x7FFFFFFFFFFFFFFF
        }
        return hashValue
    }

    private func levenshteinDistance(_ s1: String, _ s2: String, maxDistance: Int) -> Int {
        // Convert to UTF-8 bytes for SIMD operations
        let a = Array(s1.utf8)
        let b = Array(s2.utf8)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        // Early termination: if length difference > maxDistance, return sentinel value
        let lengthDiff = abs(a.count - b.count)
        if lengthDiff > maxDistance { return 999 }

        // SIMD optimization: Skip common prefix and suffix
        var startA = 0, startB = 0
        var endA = a.count, endB = b.count

        // Skip common prefix using SIMD
        while startA < endA && startB < endB {
            let remainingA = endA - startA
            let remainingB = endB - startB
            let minRemaining = min(remainingA, remainingB)

            // Process up to 16 bytes at a time with SIMD
            if minRemaining >= 16 {
                // Load 16 bytes from each string
                let vecA = simd_uchar16(
                    a[startA], a[startA+1], a[startA+2], a[startA+3],
                    a[startA+4], a[startA+5], a[startA+6], a[startA+7],
                    a[startA+8], a[startA+9], a[startA+10], a[startA+11],
                    a[startA+12], a[startA+13], a[startA+14], a[startA+15]
                )
                let vecB = simd_uchar16(
                    b[startB], b[startB+1], b[startB+2], b[startB+3],
                    b[startB+4], b[startB+5], b[startB+6], b[startB+7],
                    b[startB+8], b[startB+9], b[startB+10], b[startB+11],
                    b[startB+12], b[startB+13], b[startB+14], b[startB+15]
                )

                // Check if vectors are equal by comparing them directly
                let allEqual = (vecA == vecB)
                if allEqual {
                    startA += 16
                    startB += 16
                    continue
                } else {
                    // Find first mismatch within the 16 bytes using scalar comparison
                    for i in 0..<16 {
                        if vecA[i] != vecB[i] { break }
                        startA += 1
                        startB += 1
                    }
                    break
                }
            } else {
                // Handle remaining bytes one by one
                if a[startA] == b[startB] {
                    startA += 1
                    startB += 1
                } else {
                    break
                }
            }
        }

        // Skip common suffix using SIMD (process backwards)
        while startA < endA && startB < endB {
            let remainingA = endA - startA
            let remainingB = endB - startB
            let minRemaining = min(remainingA, remainingB)

            if minRemaining >= 16 {
                // Load 16 bytes from end of each string
                let vecA = simd_uchar16(
                    a[endA-16], a[endA-15], a[endA-14], a[endA-13],
                    a[endA-12], a[endA-11], a[endA-10], a[endA-9],
                    a[endA-8], a[endA-7], a[endA-6], a[endA-5],
                    a[endA-4], a[endA-3], a[endA-2], a[endA-1]
                )
                let vecB = simd_uchar16(
                    b[endB-16], b[endB-15], b[endB-14], b[endB-13],
                    b[endB-12], b[endB-11], b[endB-10], b[endB-9],
                    b[endB-8], b[endB-7], b[endB-6], b[endB-5],
                    b[endB-4], b[endB-3], b[endB-2], b[endB-1]
                )

                // Check if vectors are equal by comparing them directly
                if (vecA == vecB) {
                    endA -= 16
                    endB -= 16
                    continue
                } else {
                    // Find last mismatch within the 16 bytes - use scalar fallback
                    for i in (0..<16).reversed() {
                        if vecA[15-i] != vecB[15-i] { break }
                        endA -= 1
                        endB -= 1
                    }
                    break
                }
            } else {
                // Handle remaining bytes one by one
                if a[endA-1] == b[endB-1] {
                    endA -= 1
                    endB -= 1
                } else {
                    break
                }
            }
        }

        // If one string is now empty, return the length of the other
        let trimmedLenA = endA - startA
        let trimmedLenB = endB - startB
        if trimmedLenA == 0 { return trimmedLenB }
        if trimmedLenB == 0 { return trimmedLenA }

        // Now compute Levenshtein on the trimmed strings with SIMD-optimized min operations
        var distances = Array(0...trimmedLenB)

        for i in 0..<trimmedLenA {
            var newDistances = [i + 1]
            var minInRow = i + 1

            for j in 0..<trimmedLenB {
                let cost = (a[startA + i] == b[startB + j]) ? 0 : 1

                // SIMD-optimized min of 3 values
                let costs = simd_int4(Int32(distances[j + 1] + 1), Int32(newDistances[j] + 1), Int32(distances[j] + cost), Int32.max)
                let minDistance = Int(simd_reduce_min(costs))

                newDistances.append(minDistance)
                minInRow = min(minInRow, minDistance)
            }

            // Early termination: if minimum in this row > maxDistance, return sentinel value
            if minInRow > maxDistance {
                return 999
            }

            distances = newDistances
        }

        return distances.last!
    }
}

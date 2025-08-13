import Foundation
import SQLite3

class TypoService {
    private var db: OpaquePointer?

    init?(dbPath: String) {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("TypoService: Error opening database: \(String(cString: sqlite3_errmsg(db)))")
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

    func suggestTypoCorrections(for word: String, maxDistance: Int, task: DispatchWorkItem? = nil) -> [(String, Int, Int)]? {
        return queryBKTree(word: word, maxDistance: maxDistance, task: task)
    }

    private func queryBKTree(word: String, maxDistance: Int, task: DispatchWorkItem?) -> [(String, Int, Int)]? {
        guard let db = db else { return [] }
        var candidates: [(String, Int, Int)] = [] // (word, distance, frequency_rank)
        var queue: [Int] = [1] // Just node_ids for simpler queue

        while !queue.isEmpty {
            // Check if search was cancelled
            if task?.isCancelled == true {
                return nil
            }

            let nodeId = queue.removeFirst()

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
                                queue.append(childId)
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
}

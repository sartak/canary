import Foundation
import SQLite3

struct CharacterDistribution {
    private let frequencies: [Int]

    init(frequencies: [Int]) {
        precondition(frequencies.count == 26, "CharacterDistribution must have exactly 26 frequencies")
        self.frequencies = frequencies
    }

    subscript(char: Character) -> Int? {
        guard char >= "a" && char <= "z" else {
            return nil
        }
        let index = Int(char.asciiValue! - Character("a").asciiValue!)
        return frequencies[index]
    }

    func frequencyRatio(_ char1: Character, _ char2: Character) -> Double {
        let lowercased1 = Character(char1.lowercased())
        let lowercased2 = Character(char2.lowercased())
        guard let freq1 = self[lowercased1], let freq2 = self[lowercased2] else {
            return 0.5
        }
        let total = freq1 + freq2
        return total > 0 ? Double(freq1) / Double(total) : 0.5
    }

    static func fromDistributionString(_ distributionString: String) -> CharacterDistribution? {
        let counts = distributionString.split(separator: ",").compactMap { Int($0) }
        guard counts.count == 26 else { return nil }
        return CharacterDistribution(frequencies: counts)
    }
}

class FrequencyService {
    private let db: OpaquePointer

    private static let initialDistributionKey = "initial_distribution"
    private static let generalDistributionKey = "general_distribution"

    static private var initialDistribution: CharacterDistribution!
    static private var generalDistribution: CharacterDistribution!

    init(db: OpaquePointer) {
        self.db = db
        FrequencyService.loadStaticDistributions(from: db)
    }

    deinit {
        // No statements to finalize yet
    }

    private static func loadStaticDistributions(from db: OpaquePointer) {
        guard initialDistribution == nil || generalDistribution == nil else { return }

        var stmt: OpaquePointer?
        let query = "SELECT key, value FROM kv WHERE key IN ('\(initialDistributionKey)', '\(generalDistributionKey)')"

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("FrequencyService: Failed to prepare statement")
            return
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let key = String(cString: sqlite3_column_text(stmt, 0))
            let value = String(cString: sqlite3_column_text(stmt, 1))

            guard let distribution = CharacterDistribution.fromDistributionString(value) else { continue }

            switch key {
            case initialDistributionKey:
                initialDistribution = distribution
            case generalDistributionKey:
                generalDistribution = distribution
            default:
                break
            }
        }

        sqlite3_finalize(stmt)
    }

    func updateFrequencies(prefix: String, suffix: String) -> CharacterDistribution {
        if let lastChar = prefix.last, lastChar.isLetter {
            return FrequencyService.generalDistribution
        } else {
            return FrequencyService.initialDistribution
        }
    }
}

#!/usr/bin/env python3
"""
Build filtered word corpus from word frequencies and legitimate words list.

Loads word_frequencies.txt (word + frequency pairs) and filters to only include
words that appear in legitimate_words.txt, then outputs the filtered list
sorted by frequency to corpus/words.txt and creates Keyboard/words.db with
populated tables including BK-tree for typo correction.
"""

import sqlite3
import sys
from typing import Dict, Set, List, Tuple, Optional


def load_legitimate_words(filepath: str) -> Set[str]:
    """Load legitimate words into a set for fast lookup."""
    legitimate = set()
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip().lower()
            if word:
                legitimate.add(word)
    return legitimate


def load_word_frequencies(filepath: str) -> Dict[str, Tuple[str, int]]:
    """Load word frequencies from tab-separated file, preserving original capitalization."""
    frequencies = {}
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) == 2:
                original_word = parts[0]
                word_lower = original_word.lower()
                try:
                    frequency = int(parts[1])
                    frequencies[word_lower] = (original_word, frequency)
                except ValueError:
                    continue
    return frequencies


def levenshtein_distance(s1: str, s2: str) -> int:
    """Calculate Levenshtein edit distance between two strings."""
    if len(s1) < len(s2):
        return levenshtein_distance(s2, s1)

    if len(s2) == 0:
        return len(s1)

    previous_row = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row

    return previous_row[-1]


class BKTreeBuilder:
    """Builds a BK-Tree from word list and stores it in SQLite."""

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
        self.node_id = 0

    def create_bk_tables(self):
        """Create BK-Tree tables in database."""
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS bk_nodes (
                node_id INTEGER PRIMARY KEY,
                word TEXT NOT NULL,
                frequency_rank INTEGER NOT NULL
            )
        ''')

        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS bk_edges (
                parent_id INTEGER NOT NULL,
                child_id INTEGER NOT NULL,
                distance INTEGER NOT NULL,
                FOREIGN KEY (parent_id) REFERENCES bk_nodes (node_id),
                FOREIGN KEY (child_id) REFERENCES bk_nodes (node_id)
            )
        ''')

        # Index for efficient tree traversal
        self.conn.execute('CREATE INDEX IF NOT EXISTS idx_bk_edges_parent_dist ON bk_edges (parent_id, distance)')

    def insert_into_tree(self, root_id: Optional[int], word: str, frequency_rank: int) -> int:
        """Insert word into BK-Tree, returning the node ID."""
        # Create new node
        if root_id is None:
            # Root node always has ID 1
            node_id = 1
            self.node_id = 1
        else:
            self.node_id += 1
            node_id = self.node_id

        self.conn.execute('INSERT INTO bk_nodes (node_id, word, frequency_rank) VALUES (?, ?, ?)',
                         (node_id, word, frequency_rank))

        if root_id is None:
            # This is the root
            return node_id

        # Find the correct position in the tree
        current_id = root_id

        while True:
            # Get current node's word
            cursor = self.conn.execute('SELECT word FROM bk_nodes WHERE node_id = ?', (current_id,))
            current_word = cursor.fetchone()[0]

            # Calculate distance to current node
            distance = levenshtein_distance(word, current_word)

            # Check if there's already a child at this distance
            cursor = self.conn.execute(
                'SELECT child_id FROM bk_edges WHERE parent_id = ? AND distance = ?',
                (current_id, distance)
            )
            existing_child = cursor.fetchone()

            if existing_child:
                # Continue down this path
                current_id = existing_child[0]
            else:
                # Insert edge to new node
                self.conn.execute('INSERT INTO bk_edges (parent_id, child_id, distance) VALUES (?, ?, ?)',
                                (current_id, node_id, distance))
                break

        return node_id

    def build_tree(self, filtered_words: List[Tuple[str, int]]):
        """Build the complete BK-Tree from filtered words."""
        print("Building BK-Tree...")

        # Clear existing BK-Tree tables
        self.conn.execute('DROP TABLE IF EXISTS bk_edges')
        self.conn.execute('DROP TABLE IF EXISTS bk_nodes')
        self.create_bk_tables()

        root_id = None

        for i, (word, frequency) in enumerate(filtered_words):
            frequency_rank = i + 1  # Rank based on position in sorted list

            if i % 5000 == 0:
                print(f"Processed {i}/{len(filtered_words)} words...")
                self.conn.commit()  # Periodic commit

            if root_id is None:
                root_id = self.insert_into_tree(None, word, frequency_rank)
            else:
                self.insert_into_tree(root_id, word, frequency_rank)

        self.conn.commit()
        print(f"BK-Tree built successfully with {len(filtered_words)} nodes")


def create_database_tables(conn: sqlite3.Connection):
    """Create the words and words_by_suffix tables."""
    conn.execute('''
        CREATE TABLE IF NOT EXISTS words (
            word_lower TEXT NOT NULL,
            word_lower_reversed TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            word TEXT NOT NULL,
            PRIMARY KEY (word_lower, frequency_rank)
        ) WITHOUT ROWID
    ''')

    conn.execute('''
        CREATE TABLE IF NOT EXISTS words_by_suffix (
            word_lower_reversed TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            word TEXT NOT NULL,
            word_lower TEXT NOT NULL,
            PRIMARY KEY (word_lower_reversed, frequency_rank)
        ) WITHOUT ROWID
    ''')

    conn.commit()


def populate_database(conn: sqlite3.Connection, filtered_words: List[Tuple[str, int]]):
    """Populate the database tables with filtered words."""
    print("Populating database tables...")

    # Clear existing data (SQLite doesn't support TRUNCATE, so drop and recreate)
    conn.execute('DROP TABLE IF EXISTS words')
    conn.execute('DROP TABLE IF EXISTS words_by_suffix')
    create_database_tables(conn)

    words_data = []
    words_by_suffix_data = []

    for rank, (word, frequency) in enumerate(filtered_words, 1):
        word_lower = word.lower()
        word_lower_reversed = word_lower[::-1]

        # Data for words table
        words_data.append((word_lower, word_lower_reversed, rank, word))

        # Data for words_by_suffix table
        words_by_suffix_data.append((word_lower_reversed, rank, word, word_lower))

    # Batch insert for performance
    conn.executemany(
        'INSERT INTO words (word_lower, word_lower_reversed, frequency_rank, word) VALUES (?, ?, ?, ?)',
        words_data
    )

    conn.executemany(
        'INSERT INTO words_by_suffix (word_lower_reversed, frequency_rank, word, word_lower) VALUES (?, ?, ?, ?)',
        words_by_suffix_data
    )

    conn.commit()
    print(f"Populated database with {len(words_data)} words")


def build_filtered_corpus():
    """Build filtered corpus and write to words.txt and database."""
    print("Loading legitimate words...")
    legitimate_words = load_legitimate_words('corpus/legitimate_words.txt')
    print(f"Loaded {len(legitimate_words)} legitimate words")

    print("Loading word frequencies...")
    word_frequencies = load_word_frequencies('corpus/word_frequencies.txt')
    print(f"Loaded {len(word_frequencies)} word frequencies")

    print("Filtering words...")
    filtered_words = []
    for word_lower, (original_word, frequency) in word_frequencies.items():
        if word_lower in legitimate_words:
            filtered_words.append((original_word, frequency))

    print(f"Found {len(filtered_words)} words that are both frequent and legitimate")

    # Sort by frequency (descending)
    filtered_words.sort(key=lambda x: x[1], reverse=True)

    print("Writing filtered corpus to corpus/words.txt...")
    with open('corpus/words.txt', 'w', encoding='utf-8') as f:
        for word, frequency in filtered_words:
            f.write(f"{word}\n")

    print(f"Successfully wrote {len(filtered_words)} words to corpus/words.txt")

    # Create and populate database
    print("Creating database at Keyboard/words.db...")
    conn = sqlite3.connect('Keyboard/words.db')
    try:
        create_database_tables(conn)
        populate_database(conn, filtered_words)

        # Build BK-tree for typo correction
        bk_builder = BKTreeBuilder(conn)
        bk_builder.build_tree(filtered_words)

    finally:
        conn.close()

    print("Database created and populated successfully with BK-tree")


def main():
    try:
        build_filtered_corpus()
        print("Corpus build complete!")
    except FileNotFoundError as e:
        print(f"Error: Could not find required file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()

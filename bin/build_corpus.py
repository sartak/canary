#!/usr/bin/env python3
"""
Build filtered word corpus from word frequencies and legitimate words list.

Loads word_frequencies.txt (word + frequency pairs) and filters to only include
words that appear in legitimate_words.txt, then outputs the filtered list
sorted by frequency to corpus/words.txt and creates Keyboard/words.db with
populated tables.
"""

import sqlite3
import sys
from typing import Dict, Set, List, Tuple


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
    finally:
        conn.close()

    print("Database created and populated successfully")


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

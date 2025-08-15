#!/usr/bin/env python3
"""
Build filtered word corpus from word frequencies and legitimate words list.

Loads word_frequencies.txt (ordered word list) and filters to only include
words that appear in legitimate_words.txt, then outputs the filtered list
to corpus/words.txt and creates Keyboard/words.db with populated tables.
"""

import os
import re
import sqlite3
import sys
from collections import Counter
from typing import Dict, Set, List, Tuple, Optional


def process_big_txt(filepath: str) -> tuple[Counter, Counter]:
    """Load corpus/big.txt and process each \\S+ word. Count frequency of first letters and all letters."""
    first_letter_counts = Counter()
    general_letter_counts = Counter()
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()
        # Find all non-whitespace sequences
        words = re.findall(r'\S+', text)
        for word in words:
            # Lowercase and strip non a-z characters
            processed_word = re.sub(r'[^a-z]', '', word.lower())
            if processed_word:  # Only count non-empty words
                # Count first letter
                first_letter = processed_word[0]
                first_letter_counts[first_letter] += 1
                # Count all letters
                for letter in processed_word:
                    general_letter_counts[letter] += 1
    return first_letter_counts, general_letter_counts


def load_legitimate_words(filepath: str) -> Set[str]:
    """Load legitimate words into a set for fast lookup."""
    legitimate = set()
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip().lower()
            if word:
                legitimate.add(word)
    return legitimate


def load_word_list(filepath: str) -> Dict[str, Tuple[str, int]]:
    """Load ordered word list, preserving original capitalization and assigning rank as frequency."""
    word_list = {}
    with open(filepath, 'r', encoding='utf-8') as f:
        for rank, line in enumerate(f, 1):
            original_word = line.strip()
            if original_word:
                word_lower = original_word.lower()
                word_list[word_lower] = (original_word, rank)
    return word_list


def load_hidden_words(filepath: str) -> Set[str]:
    """Load hidden words into a set for fast lookup."""
    hidden = set()
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip().lower()
            if word:
                hidden.add(word)
    return hidden


def hash_string(s: str) -> int:
    """Simple hash function for strings - consistent with Swift."""
    hash_value = 0
    for char in s:
        hash_value = (hash_value * 31 + ord(char)) & 0x7FFFFFFFFFFFFFFF
    return hash_value


def generate_deletes(word: str, max_edit_distance: int = 2) -> Set[str]:
    """Generate all possible deletes for a word up to max_edit_distance."""
    deletes = set()

    def generate_deletes_recursive(word: str, edit_distance: int):
        deletes.add(word)
        if edit_distance < max_edit_distance:
            for i in range(len(word)):
                if len(word) > 1:  # Don't delete if it would make empty string
                    delete = word[:i] + word[i+1:]
                    if delete not in deletes:
                        generate_deletes_recursive(delete, edit_distance + 1)

    generate_deletes_recursive(word, 0)
    return deletes


def populate_symspell_tables(conn: sqlite3.Connection, filtered_words: List[Tuple[str, int]], hidden_words: Set[str]):
    """Populate SymSpell tables with deletes pointing to main words table."""
    print("Building SymSpell dictionary...")

    deletes_data = []

    for i, (word, original_rank) in enumerate(filtered_words):
        word_lower = word.lower()

        # Skip hidden words - they should never appear in autocorrect suggestions
        if word_lower in hidden_words:
            continue

        frequency_rank = i + 1  # Rank based on position in sorted list

        # Generate deletes for this word
        deletes = generate_deletes(word_lower, max_edit_distance=2)
        for delete in deletes:
            delete_hash = hash_string(delete)
            deletes_data.append((delete_hash, word_lower, frequency_rank, word))

        if i % 1000 == 0:
            print(f"Processed {i}/{len(filtered_words)} words for SymSpell...")

    # Batch insert with duplicate handling
    conn.executemany(
        'INSERT OR IGNORE INTO symspell_deletes (delete_hash, word_lower, frequency_rank, word) VALUES (?, ?, ?, ?)',
        deletes_data
    )

    conn.commit()
    print(f"SymSpell dictionary built with {len(deletes_data)} deletes")



def create_database_tables(conn: sqlite3.Connection):
    """Create all database tables and indexes."""
    # Main words table
    conn.execute('''
        CREATE TABLE words (
            word_lower TEXT NOT NULL,
            word_lower_reversed TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            word TEXT NOT NULL,
            hidden INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (word_lower, frequency_rank)
        ) WITHOUT ROWID
    ''')

    # Suffix lookup table
    conn.execute('''
        CREATE TABLE words_by_suffix (
            word_lower_reversed TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            word TEXT NOT NULL,
            word_lower TEXT NOT NULL,
            hidden INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (word_lower_reversed, frequency_rank)
        ) WITHOUT ROWID
    ''')

    # SymSpell table for typo correction with covering index data
    conn.execute('''
        CREATE TABLE symspell_deletes (
            delete_hash INTEGER NOT NULL,
            word_lower TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            word TEXT NOT NULL,
            PRIMARY KEY (delete_hash, word_lower)
        ) WITHOUT ROWID
    ''')

    # Prefix lookup table for fast typeahead completion
    conn.execute('''
        CREATE TABLE prefixes (
            prefix_lower TEXT NOT NULL,
            word TEXT NOT NULL,
            frequency_rank INTEGER NOT NULL,
            hidden INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (prefix_lower, frequency_rank)
        ) WITHOUT ROWID
    ''')

    # Key-value table for storing distributions and other data
    conn.execute('''
        CREATE TABLE kv (
            key TEXT NOT NULL PRIMARY KEY,
            value TEXT NOT NULL
        ) WITHOUT ROWID
    ''')

    # Covering index for eliminating JOIN - everything needed is in the index
    conn.execute('CREATE INDEX idx_symspell_covering ON symspell_deletes (delete_hash, frequency_rank, word)')

    conn.commit()


def populate_prefixes_table(conn: sqlite3.Connection, filtered_words: List[Tuple[str, int]], hidden_words: Set[str]):
    """Populate the prefixes table with all possible prefixes for each word, capped at 20 visible entries per prefix."""
    print("Building prefixes table...")

    prefixes_data = []
    prefix_visible_counts = {}

    for rank, (word, original_rank) in enumerate(filtered_words, 1):
        word_lower = word.lower()
        is_hidden = 1 if word_lower in hidden_words else 0

        # Generate all prefixes for this word (1 to full length)
        for i in range(1, len(word_lower) + 1):
            prefix = word_lower[:i]

            # Always include hidden words, but cap visible words at 20 per prefix
            if is_hidden or prefix_visible_counts.get(prefix, 0) < 20:
                prefixes_data.append((prefix, word, rank, is_hidden))
                if not is_hidden:
                    prefix_visible_counts[prefix] = prefix_visible_counts.get(prefix, 0) + 1

    # Batch insert for performance
    conn.executemany(
        'INSERT INTO prefixes (prefix_lower, word, frequency_rank, hidden) VALUES (?, ?, ?, ?)',
        prefixes_data
    )

    conn.commit()
    print(f"Populated prefixes table with {len(prefixes_data)} prefix entries (capped at 20 visible per prefix)")


def populate_database(conn: sqlite3.Connection, filtered_words: List[Tuple[str, int]], hidden_words: Set[str]):
    """Populate the database tables with filtered words."""
    print("Populating database tables...")

    words_data = []
    words_by_suffix_data = []

    for rank, (word, original_rank) in enumerate(filtered_words, 1):
        word_lower = word.lower()
        word_lower_reversed = word_lower[::-1]
        is_hidden = 1 if word_lower in hidden_words else 0

        # Data for words table
        words_data.append((word_lower, word_lower_reversed, rank, word, is_hidden))

        # Data for words_by_suffix table
        words_by_suffix_data.append((word_lower_reversed, rank, word, word_lower, is_hidden))

    # Batch insert for performance
    conn.executemany(
        'INSERT INTO words (word_lower, word_lower_reversed, frequency_rank, word, hidden) VALUES (?, ?, ?, ?, ?)',
        words_data
    )

    conn.executemany(
        'INSERT INTO words_by_suffix (word_lower_reversed, frequency_rank, word, word_lower, hidden) VALUES (?, ?, ?, ?, ?)',
        words_by_suffix_data
    )

    conn.commit()
    print(f"Populated database with {len(words_data)} words")


def populate_kv_table(conn: sqlite3.Connection):
    """Populate the kv table with initial and general letter distributions from big.txt."""
    print("Processing big.txt for letter distributions...")
    first_letter_counts, general_letter_counts = process_big_txt('corpus/big.txt')

    # Create ordered list of initial letter counts for a-z
    initial_values = []
    for letter in 'abcdefghijklmnopqrstuvwxyz':
        count = first_letter_counts.get(letter, 0)
        initial_values.append(str(count))

    # Create ordered list of general letter counts for a-z
    general_values = []
    for letter in 'abcdefghijklmnopqrstuvwxyz':
        count = general_letter_counts.get(letter, 0)
        general_values.append(str(count))

    # Insert both distributions into kv table
    initial_csv = ','.join(initial_values)
    general_csv = ','.join(general_values)

    conn.execute('INSERT INTO kv (key, value) VALUES (?, ?)', ('initial_distribution', initial_csv))
    conn.execute('INSERT INTO kv (key, value) VALUES (?, ?)', ('general_distribution', general_csv))
    conn.commit()

    print(f"Stored initial letter distribution: {initial_csv}")
    print(f"Stored general letter distribution: {general_csv}")


def build_filtered_corpus():
    """Build filtered corpus and write to words.txt and database."""
    print("Loading legitimate words...")
    legitimate_words = load_legitimate_words('corpus/legitimate_words.txt')
    print(f"Loaded {len(legitimate_words)} legitimate words")

    print("Loading word list...")
    word_list = load_word_list('corpus/word_frequencies.txt')
    print(f"Loaded {len(word_list)} words")

    print("Loading hidden words...")
    hidden_words = load_hidden_words('corpus/hidden_words.txt')
    print(f"Loaded {len(hidden_words)} hidden words")

    print("Filtering words...")
    filtered_words = []
    for word_lower, (original_word, rank) in word_list.items():
        if word_lower in legitimate_words or word_lower in hidden_words:
            filtered_words.append((original_word, rank))

    print(f"Found {len(filtered_words)} words that are both frequent and legitimate or hidden")

    # Sort by rank (ascending - lower rank = higher frequency)
    filtered_words.sort(key=lambda x: x[1])

    print("Writing filtered corpus to corpus/words.txt...")
    with open('corpus/words.txt', 'w', encoding='utf-8') as f:
        for word, rank in filtered_words:
            f.write(f"{word}\n")

    print(f"Successfully wrote {len(filtered_words)} words to corpus/words.txt")

    # Remove existing database and create fresh one
    db_path = 'Keyboard/words.db'
    if os.path.exists(db_path):
        os.remove(db_path)
        print(f"Removed existing database: {db_path}")

    print("Creating database at Keyboard/words.db...")
    conn = sqlite3.connect(db_path)
    try:
        create_database_tables(conn)
        populate_database(conn, filtered_words, hidden_words)
        populate_prefixes_table(conn, filtered_words, hidden_words)
        populate_symspell_tables(conn, filtered_words, hidden_words)
        populate_kv_table(conn)

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

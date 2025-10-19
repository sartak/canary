# Swipe-to-Type Implementation Notes

## Problem Statement

Converting continuous finger gestures across a keyboard into intended words. This is significantly more complex than simple key-sequence matching due to the noisy nature of swipe input.

## Key Insights

### Real vs Intended Input
- **Intended**: User wants to type "hello" (h-e-l-l-o)
- **Actual gesture path**: `hgfrertyuiklo` (finger crosses many intermediate keys)
- **Challenge**: Extract intended word from noisy key sequence

### Human Behavior Patterns
1. **First/Last Letter Accuracy**: Users start and end gestures precisely on intended letters
2. **Intent Points**: Users pause, change direction, or "squiggle" on important letters (especially repeated letters like 'll' in "hello")
3. **Path Crossing**: Finger naturally crosses intermediate keys between target letters

## Core Algorithm Approach

### 1. First/Last Letter Constraint
- **Assumption**: First and last detected letters match intended word exactly
- **Implementation**: Index dictionary by `(first_letter, last_letter)` pairs
- **Benefit**: Dramatically reduces search space

### 2. Path Processing Pipeline
```
Raw gesture path → Intent point detection → Letter sequence → Dictionary lookup → Ranked candidates
```

### 3. Intent Point Detection
- Detect **pauses** in finger movement (velocity drops)
- Identify **direction changes** (significant heading changes)
- Find **squiggles** or **repeated motion** in small areas
- Map these points to nearest keys as "intended letters"

### 4. Key Detection Strategy
- **Hit zones**: Use expanded touch areas around keys (larger than visual boundaries)
- **Proximity weighting**: Consider keys passed near, not just keys directly touched
- **Primary**: Use intent points to generate clean letter sequence
- **Fallback**: Use deduplicated key sequence from all detected keys
- Remove adjacent duplicate letters: `hgfrertyuiklo` → `hgfretyuklo`

## Dictionary Lookup Strategy

### Index Structure
```swift
let firstLastIndex: [Character, Character]: [String] = [
    ('h', 'o'): ["hello", "hero", "halo", ...],
    ('t', 'e'): ["type", "take", "taste", ...],
    ...
]
```

### Subsequence Matching
1. Get candidates from `firstLastIndex[(firstLetter, lastLetter)]`
2. For each candidate word, check if middle letters appear as subsequence in detected sequence
3. Example: "hello" middle letters "ell" should appear in order within "gfretyukl"

### Ranking Criteria
1. **Word frequency**: Common words ranked higher
2. **Gesture confidence**: How well path matches expected letter positions
3. **Subsequence match quality**: Fewer skipped letters = better match
4. **Context**: Previous words in sentence (future enhancement)

## Memory Optimization

### Constraints
- Stay under 30MB RAM limit
- Dictionary can be large but most data should live in Core Data
- Only keep working set in memory

### Strategy
- Pre-compute first/last letter index for common words (~50k most frequent)
- Store full dictionary in Core Data
- Lazy load less common words as needed
- Cache recently used word patterns

## Implementation Phases

### Phase 1: Basic Subsequence Matching
- Implement first/last letter constraint
- Simple deduplication of adjacent letters
- Basic dictionary lookup with frequency ranking

### Phase 2: Intent Point Detection
- Add gesture analysis for pauses and direction changes
- Improve letter sequence extraction
- Better handling of repeated letters

### Phase 3: Advanced Features
- Context-aware predictions
- Learning from user patterns
- Adaptive gesture recognition

## Technical Considerations

### Performance
- **Continuous decoding**: Algorithm must update predictions on every new touchpoint
- **Sub-frame latency**: Each prediction update must complete before next touch event
- Real-time processing during gesture (no lag)
- Background thread for dictionary operations
- Efficient data structures for fast lookup

### User Experience
- **Real-time feedback**: Decoder runs continuously during gesture, updating suggestions on each touchpoint
- **Progressive prediction**: Show candidate words as soon as gesture starts, not after finger lifts
- Visual feedback during gesture (path visualization)
- Immediate candidate display
- Graceful fallback to character-by-character input if gesture fails

### Edge Cases
- Very short gestures (2-3 letters)
- Gestures that don't match any dictionary words
- Accidental touches/false starts
- Different finger sizes and gesture styles
- **Error correction scenarios**:
  - Overshoot (finger goes past intended key)
  - Direction errors (slight curve toward wrong key)  
  - Near misses (finger passes close to but not over intended key)
  - Note: Complex error correction not critical - users can delete and retry

## Technical Resources and References

### Dictionary Source

"To build our dictionary we used the Google Web Trillion Word Corpus as compiled by Peter Norvig. This corpus contains approximately 300,000 of the most commonly used words in the English language and their frequencies. Unfortunately, more than half of these are misspelled words and abbreviations. To get rid of these we cross checked against The Official Scrabble Dictionary, the Most Common Boys/Girls Names, and WinEdt's US Dictionary, including only words that appeared in at least one of them. This left us with 95,881 words or about five times the vocabulary of an average adult."

### Datasets

* https://osf.io/sj67f/
* https://huggingface.co/datasets/futo-org/swipe.futo.org

### Academic and Research Articles

**1. "Finding an Optimal Keyboard Layout for Swype" - sangaline.com**
https://sangaline.com/post/finding-an-optimal-keyboard-layout-for-swype/
- **Key Insight**: Introduces "string form" representation (e.g., "pot" → "poiuyt" on QWERTY)
- **Algorithm**: Hash table mapping string forms to candidate words, then careful evaluation
- **Mathematical Analysis**: Detailed probability models for swipe pattern optimization

**2. "How We Use Deep Learning for Swipe Typing on the Grammarly iOS Keyboard"**
https://www.grammarly.com/blog/engineering/deep-learning-swipe-typing/
- **Key Insight**: Traditional shape-based algorithms (dynamic time warping) are brittle
- **Evolution**: Shape similarity → Neural networks trained on gesture data
- **Production Experience**: Neural approach captures patterns that manual encoding missed

### Industry Implementation Details

**3. "The Machine Intelligence Behind Gboard" - Google Research**
https://research.google/blog/the-machine-intelligence-behind-gboard/
- **Neural Spatial Models**: Handle "fat finger" typing and spatially similar gestures
- **Finite State Transducers**: Probabilistic n-gram models with spatial likelihood
- **Performance**: 6x faster, 10x smaller models; 15% fewer bad autocorrects, 10% fewer wrong gesture decodes
- **Beam Search**: Combined language and spatial models for real-time processing

**4. "How Swipe Typing Works" - Fleksy Blog**
https://www.fleksy.com/blog/how-swipe-typing-works/
- **Beam Search Algorithm**: Aggressive pruning of invalid search paths
- **Data Structure**: Directed Acyclic Graph (DAG) for dictionary representation
- **Scoring**: Spatial probability model considering every point in the swipe path
- **Multi-Dictionary**: Uses multiple word lists for comprehensive coverage

**5. Practical Implementation - GitHub**
https://github.com/Neargye/SwipeType
- **Real Code**: Swype algorithm implementation for .NET and Unity
- **Reference**: Concrete example of algorithm in practice

### Core Algorithm Insights from Research

**String Subsequence Problem**: All sources confirm this is fundamentally a subsequence matching challenge with spatial constraints.

**Hybrid Approaches Work Best**:
- Start with geometric/spatial models
- Add probabilistic language models
- Enhanced with neural networks for complex patterns

**Performance Optimization Critical**:
- Real-time constraints require aggressive optimization
- Beam search with pruning is standard approach
- Memory and computation trade-offs are essential

**Production Lessons**:
- Shape-based algorithms hit accuracy ceilings
- Neural approaches require substantial training data
- First/last letter constraints align with industry practices
- Spatial probability models outperform pure geometric matching

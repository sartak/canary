# Canary Keyboard - Technical Requirements

## Core Architecture

### App Structure
- **Type**: iOS Keyboard Extension (standalone app)
- **Language**: Swift
- **Target**: Latest iOS version
- **Deployment**: Direct Xcode deployment (personal use)
- **Devices**: iPhone and iPad with adaptive layouts (including iPad floating keyboard)

### Layout System
- **Base Layout**: Canary keyboard layout (user-provided design)
- **Configurable Layouts**: Support for Canary and QWERTY keyboard layouts
- **Layout Switching**: Allow users to switch between different layouts
- **Layer System**: Multiple persistent layers (letters, symbols, numbers)
- **Layer Switching**: Tap-to-toggle (like iOS default), not hold-based
- **Responsive Design**: Adaptive layout for different screen sizes and orientations
- **Future-Proof**: Flexible enough for new Apple form factors

## Input Methods

### Primary Input
- **Tap Typing**: Standard hunt-and-peck for precise character entry
- **Adaptive Hitboxes**: Adjust key touch areas based on likely next letters
- **Swipe-to-Type**: Full word prediction from continuous gesture paths across letters
- **Hold for Alternates**: Long-press any key to access accent marks and alternative characters
- **Context Adaptation**: Adapt keyboard layout and suggestions based on UIKeyboardType traits
- **Text Input Traits**: Respond to UITextInputTraits properties (autocapitalization, autocorrection, smart quotes, etc.)
- **Key Repeat**: Hold backspace to continuously delete characters
- **Caps Lock**: Double-tap shift or dedicated caps lock key for all-caps typing
- **Multi-Touch Typing**: Support simultaneous key presses with ordered activation - touch downs are processed in order, but any touch up activates all keys in the queue up to and including that key, allowing for faster typing patterns (e.g., A down → B down → C down → C up produces "ABC")

### Text Processing
- **Text Expansion**: Custom shortcuts that expand to frequently used phrases
- **Word Completion**: Intelligent suggestions based on context and typing patterns
- **Learning System**: Adapt to user vocabulary (technical terms, slang, new words)
- **Frequency Tracking**: Learn which words user types most often
- **Smart Backspace**: Context-aware deletion - single characters, complete words, or prediction completions
- **Auto-Correction**: Automatic typo correction and capitalization using iOS text checking APIs
- **Copy/Paste Operations**: Clipboard access using UIPasteboard (requires full access permissions)

## Technical Constraints

### Security & Permissions
- **No Special Entitlements**: Must work within standard App Extension sandbox
- **App Compatibility**: Work in all standard apps (limited functionality in secure text fields acceptable)
- **Privacy**: All learning and storage kept local to device

### Performance
- **Responsiveness**: Low-latency gesture recognition and typing feedback
- **UI Creation**: Create all UI programmatically - storyboards cause 1+ second delays in keyboard extensions
- **Memory Constraints**: Stay under 60MB RAM limit to avoid extension termination
- **Memory Pressure Handling**: Respond to low memory notifications by releasing non-essential resources
- **Efficiency**: Optimized for battery life and memory usage
- **Reliability**: Graceful handling of edge cases and errors

## Data & Storage

### Dictionary System
- **iOS Integration**: UILexicon access to user's personal dictionary and learned words
- **UITextChecker**: iOS suggestions and built-in spell checking
- **Custom Lexicon**: Our own vocabulary data for enhanced predictions
- **Architecture**: Pluggable system combining iOS sources with custom dictionaries
- **Learning Storage**: Local persistence of user vocabulary and frequency data
- **New Word Detection**: Automatically learn and store new words typed by user

### Data Persistence
- **Local Storage**: CoreData for user preferences and learned data (no disk space limits)
- **Memory Management**: Lazy loading of data to stay within 60MB RAM constraint
- **Shared Container**: Settings and configuration shared between main app and keyboard extension
- **Cross-Device Sync**: Encrypted iCloud sync for user dictionary and settings
- **Data Privacy**: Local-first processing with secure cloud sync

## User Interface

### Key Features
- **Multi-Layer Support**: Visual indicators for current layer and available layers
- **Gesture Feedback**: Visual feedback during swipe-to-type operations
- **Suggestion Bar**: Word completion suggestions above keyboard
- **Hold Menus**: Pop-up menus for alternative characters
- **Keyboard Switching**: Globe/next keyboard button for switching to other keyboards
- **Keyboard Dismissal**: Button to dismiss/hide the keyboard when editing is complete

### Accessibility
- **VoiceOver**: Basic support for screen readers
- **Dynamic Type**: Respect user's preferred text size settings
- **High Contrast**: Work well with iOS accessibility display options
- **Dark Mode**: Support both light and dark appearance modes

## Development Approach

### Implementation Strategy
- **Modular Design**: Separate concerns (layout, input processing, predictions, storage)
- **Testable Architecture**: Components that can be unit tested independently
- **Incremental Development**: Start with basic functionality, add advanced features iteratively

### Testing Strategy
- **Primary Testing**: Direct device deployment via Xcode
- **Fallback**: Keep existing keyboard available during development
- **Test Coverage**: Focus on core typing scenarios and edge cases

## Future Extensibility

### Planned Enhancements
- Custom dictionary import/export
- Advanced gesture recognition
- Performance optimizations

### Architecture Considerations
- Plugin-style architecture for easy feature addition
- Clean separation between layout definition and input processing
- Extensible prediction system for future AI integration
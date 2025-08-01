# Canary Keyboard - Implementation Plan

## Milestone 1: Basic Keyboard Foundation
**Goal**: Get a live keyboard extension running on iOS that works end-to-end

### Project Setup
- [x] Create new iOS app project with keyboard extension target
- [x] Configure proper entitlements and Info.plist settings for keyboard extension
- [x] Verify app builds and runs on device

### Basic Keyboard UI
- [x] Create minimal keyboard view controller
- [x] Add two basic key buttons (e.g., 'A' and 'B')
- [x] Add globe/next keyboard button with proper switching functionality ([Apple docs](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html#//apple_ref/doc/uid/TP40014214-CH16-SW4))
- [x] Implement basic key press handling

### iOS Integration
- [x] Verify keyboard can be enabled and selected
- [x] Test basic character input works in multiple apps

## Milestone 2: Self-Hosting Keyboard
**Goal**: Complete Canary layout that can handle everyday English typing

### Implement Alphabet Entry
- [x] Define Canary layout data structure
- [x] Create dynamic key generation from layout definition
- [x] Render all letters (a-z) with proper Canary positioning
- [x] Make each letter produce its character on press
- [x] Make space, backspace, and return keys perform their respective actions

### Keyboard Layers
- [x] Create layer switching mechanism and state management
- [x] Add shift layer for capitals
- [x] Implement complete symbol layer with all punctuation and symbols
- [x] Implement number layer

## Milestone 3: Layout Flexibility
**Goal**: Make keyboard adapt to different devices, orientations, and layouts

### Responsive Design
- [x] Implement adaptive layout for different screen sizes
- [x] Handle orientation changes and landscape mode
- [x] Test on iPhone and iPad in all orientations
- [x] Test iPad floating keyboard mode

### Layout Configuration
- [x] Add QWERTY layout
- [x] Add layout selection UI

## Milestone 4: UI Polish
**Goal**: Make keyboard look and feel great

### UI Improvements
- [x] Add visual key press feedback
- [x] Add haptic feedback for key presses
- [x] Support light and dark mode
- [x] Add keyboard dismiss button using dismissKeyboard()
- [x] Add key repeat for backspace (hold to continuously delete)
- [x] Implement caps lock functionality (double-tap shift gesture)
- [x] Remove incorrect animation when the keyboard initially launches
- [x] Improve layout for iPad (floating keyboard mode, corner radius, smaller gaps)

## Milestone 5: Advanced Input
**Goal**: Additional gesture-based input features

### Hold Gesture System
- [x] Implement long-press gesture recognition
- [ ] Create popup menu system for alternates
- [ ] Define alternate character mappings
- [ ] Add touch-and-drag selection in popups

### Additional Gestures
- [ ] Implement spacebar drag for cursor movement
- [ ] Add context-aware key alternates (e.g., domain suffixes for email fields)
- [ ] iPad: Add pinch to toggle floating keyboard

## Milestone 6: Copy/Paste Keys
**Goal**: Add dedicated clipboard access keys

### Clipboard Integration
- [ ] Add copy and paste keys to keyboard layout
- [ ] Implement UIPasteboard operations with full access ([Apple docs](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW8))
- [ ] Test clipboard functionality across apps

## Milestone 7: Basic Predictions
**Goal**: Add word suggestions using iOS text prediction APIs

### Prediction Integration
- [ ] Integrate with iOS UITextChecker and prediction APIs
- [ ] Access UILexicon for user's personal dictionary and learned words
- [ ] Create suggestion bar above keyboard
- [ ] Implement suggestion selection and insertion
- [ ] Implement smart backspace (context-aware deletion)
- [ ] Add enhanced auto-correction with prediction integration
- [ ] Respect UITextInputTraits settings (autocapitalization, autocorrection preferences)
- [ ] Adjust key touch areas based on next letter probability

## Milestone 8: Swipe-to-Type Foundation
**Goal**: Basic gesture recognition for swipe typing

### Gesture Recognition
- [ ] Implement touch tracking across keyboard
- [ ] Create gesture path recording system
- [ ] Add visual feedback during swipe gestures
- [ ] Create basic path-to-word prediction algorithm
- [ ] Track accuracy based on whether word was corrected, for further fine-tuning

## Milestone 9: Learning and Adaptation
**Goal**: Make keyboard learn user patterns and vocabulary

### Data Storage
- [ ] Implement local storage system (Core Data)
- [ ] Create user dictionary for new words
- [ ] Add frequency tracking for typed words
- [ ] Enhance predictions with learned vocabulary
- [ ] Implement memory pressure response (release caches, unload unused data)

## Milestone 10: Text Expansion
**Goal**: Add custom shortcuts that expand to longer phrases

### Shortcut System
- [ ] Create shortcut definition and storage system
- [ ] Implement shortcut detection during typing
- [ ] Add automatic expansion when shortcuts are typed
- [ ] Create UI for managing custom shortcuts in main app
- [ ] Use shared container to pass settings between app and keyboard extension

## Milestone 11: Cross-Device Sync
**Goal**: Sync settings and learned vocabulary across devices

### iCloud Integration
- [ ] Implement encrypted iCloud sync for user dictionary
- [ ] Sync keyboard settings and preferences
- [ ] Handle sync conflicts and merging


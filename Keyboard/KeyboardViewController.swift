//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let largeScreenWidth: CGFloat = 600
private let dismissButtonSize: CGFloat = 24

class KeyboardViewController: UIInputViewController {
    private var currentLayer: Layer = .alpha
    private var userShiftState: ShiftState = .unshifted
    private var appShiftState: ShiftState = .unshifted
    private var userShiftOverride: Bool = false
    private var keyboardTouchView: KeyboardTouchView!
    private var deviceLayout: DeviceLayout!
    private var heightConstraint: NSLayoutConstraint?
    private var keyboardLayout: KeyboardLayout = .canary
    private var needsGlobe: Bool = false
    private var keyPopouts: [Int: UIView] = [:]
    private var dismissButton: UIButton!
    private var cutButton: UIButton!
    private var copyButton: UIButton!
    private var pasteButton: UIButton!
    private var suggestionView: SuggestionView!
    private var suggestionService: SuggestionService!
    private var pendingRefresh = false
    private var maybePunctuating = false
    private var autocorrectAppDisabled = false
    private var autocorrectUserDisabled = false
    private var autocompleteWordDisabled = false
    private var undoActions: [InputAction]?

    // Expose autocorrect state for testing/debugging
    var isAutocorrectEnabled: Bool {
        return !autocorrectAppDisabled && !autocorrectUserDisabled
    }

    // Key repeat support
    private var keyRepeatTimer: Timer?
    private var currentlyRepeatingKey: KeyData?
    private let keyRepeatInitialDelay: TimeInterval = 0.5
    private let keyRepeatInterval: TimeInterval = 0.05

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (traitEnvironment: UITraitEnvironment, previousTraitCollection: UITraitCollection) in
            self?.keyboardTouchView?.setNeedsDisplay()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let currentBounds = view.bounds
        let screenBounds = UIScreen.main.bounds

        // Always setup keyboard initially
        if keyboardTouchView == nil {
            needsGlobe = needsInputModeSwitchKey
            updateAutocorrectSettings()
            setupKeyboard()

            // If bounds seem wrong (full screen on iPad), schedule a rebuild
            if currentBounds.width >= screenBounds.width * 0.95 && screenBounds.width > 1000 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.view.bounds != currentBounds {
                        self.rebuildKeyboard()
                    }
                }
            }
        } else {
            // Rebuild when bounds change
            let lastWidth = keyboardTouchView.bounds.width
            if abs(currentBounds.width - lastWidth) > 10 {
                rebuildKeyboard()
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.rebuildKeyboard()
        }
    }

    private func setupKeyboard() {
        let screenBounds = UIScreen.main.bounds
        let viewBounds = view.bounds
        let isLandscape = screenBounds.width > screenBounds.height

        let effectiveWidth = viewBounds.width
        let effectiveHeight = isLandscape ? screenBounds.width : screenBounds.height

        deviceLayout = DeviceLayout.forCurrentDevice(containerWidth: effectiveWidth, containerHeight: effectiveHeight)

        keyboardTouchView = KeyboardTouchView()
        keyboardTouchView.backgroundColor = UIColor.clear
        keyboardTouchView.shiftState = effectiveShiftState()
        keyboardTouchView.deviceLayout = deviceLayout
        keyboardTouchView.autocorrectEnabled = !autocorrectUserDisabled
        keyboardTouchView.keyData = createKeyData()
        keyboardTouchView.setNeedsDisplay()

        keyboardTouchView.onKeyTouchDown = { [weak self] keyData in
            self?.handleKeyTouchDown(keyData)
        }

        keyboardTouchView.onKeyTouchUp = { [weak self] keyData in
            self?.handleKeyTouchUp(keyData)
        }

        keyboardTouchView.onKeyLongPress = { [weak self] keyData in
            self?.handleKeyLongPress(keyData)
        }

        keyboardTouchView.onKeyDoubleTap = { [weak self] keyData in
            self?.handleKeyDoubleTap(keyData)
        }

        keyboardTouchView.onAlternateSelected = { [weak self] alternate, keyData in
            self?.handleAlternateSelected(alternate, from: keyData)
        }

        // Set up alternates callbacks on the gesture recognizer
        keyboardTouchView.gestureRecognizer.onAlternatesShow = { [weak self] keyData, alternates in
            self?.showAlternatesPopup(for: keyData, alternates: alternates)
        }

        keyboardTouchView.gestureRecognizer.onAlternatesMove = { [weak self] point in
            self?.keyboardTouchView.updateAlternatesSelection(at: point)
        }

        keyboardTouchView.gestureRecognizer.onAlternatesSelect = { [weak self] in
            self?.keyboardTouchView.selectCurrentAlternate()
        }

        keyboardTouchView.gestureRecognizer.onAlternatesDismiss = { [weak self] in
            self?.keyboardTouchView.dismissAlternatesPopup()
        }

        // Calculate keyboard height first
        let isShifted: Bool
        switch effectiveShiftState() {
        case .unshifted:
            isShifted = false
        case .shifted, .capsLock:
            isShifted = true
        }
        let calculatedHeight = deviceLayout.totalKeyboardHeight(for: currentLayer, shifted: isShifted, layout: keyboardLayout, needsGlobe: needsGlobe)

        // Disable implicit animations during initial keyboard setup to prevent keys sliding in from corners
        UIView.performWithoutAnimation {
            view.addSubview(keyboardTouchView)

            keyboardTouchView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                keyboardTouchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                keyboardTouchView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                keyboardTouchView.topAnchor.constraint(equalTo: view.topAnchor),
                keyboardTouchView.heightAnchor.constraint(equalToConstant: calculatedHeight)
            ])

            // Set explicit height constraint for the main view
            heightConstraint = NSLayoutConstraint(
                item: view as Any,
                attribute: .height,
                relatedBy: .equal,
                toItem: nil,
                attribute: .notAnAttribute,
                multiplier: 1.0,
                constant: calculatedHeight
            )
            heightConstraint?.priority = UILayoutPriority(999)
            view.addConstraint(heightConstraint!)

            setupDismissButton()
            setupEditingButtons()
            setupSuggestionView()
        }
    }

    private func createKeyData() -> [KeyData] {
        var keys: [KeyData] = []
        var yOffset: CGFloat = deviceLayout.topPadding

        let isShifted: Bool
        switch effectiveShiftState() {
        case .unshifted:
            isShifted = false
        case .shifted, .capsLock:
            isShifted = true
        }
        for (rowIndex, row) in keyboardLayout.nodeRows(for: currentLayer, shifted: isShifted, layout: deviceLayout, needsGlobe: needsGlobe).enumerated() {
            let rowKeys = createRowKeyData(for: row, rowIndex: rowIndex, yOffset: yOffset, startingIndex: keys.count)
            keys.append(contentsOf: rowKeys)
            yOffset += deviceLayout.keyHeight + deviceLayout.verticalGap
        }

        return keys
    }

    private func createRowKeyData(for row: [Node], rowIndex: Int, yOffset: CGFloat, startingIndex: Int) -> [KeyData] {
        let containerWidth = view.bounds.width
        let rowWidth = Node.calculateRowWidth(for: row)
        let rowStartX = (containerWidth - rowWidth) / 2
        var xOffset: CGFloat = rowStartX
        var keys: [KeyData] = []

        for node in row {
            switch node {
            case .key(let key, let keyWidth):
                let frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: deviceLayout.keyHeight)
                _ = view.bounds.width > largeScreenWidth
                let keyData = KeyData(
                    index: startingIndex + keys.count,
                    key: key,
                    frame: frame
                )
                keys.append(keyData)
                xOffset += keyWidth
            case .gap(let gapWidth):
                xOffset += gapWidth
            case .split(let splitWidth):
                xOffset += splitWidth
            }
        }

        return keys
    }





    private func handleKeyTouchDown(_ keyData: KeyData) {
        keyboardTouchView.setNeedsDisplay()

        // Provide haptic feedback for key press
        HapticFeedback.shared.keyPress(for: keyData.key, hasFullAccess: hasFullAccess)

        let isLargeScreen = view.bounds.width > largeScreenWidth
        if case .simple = keyData.key.keyType, !isLargeScreen {
            keyboardTouchView.keysWithPopouts.insert(keyData.index)
            showKeyPopout(for: keyData)
        }
    }

    private func handleKeyTouchUp(_ keyData: KeyData) {
        keyboardTouchView.setNeedsDisplay()

        keyboardTouchView.keysWithPopouts.remove(keyData.index)
        hideKeyPopout(for: keyData)

        // Stop key repeat if this key was repeating
        stopKeyRepeat()

        // Handle the key tap (only if it wasn't a long press that triggered repeat)
        if currentlyRepeatingKey == nil || currentlyRepeatingKey?.index != keyData.index {
            performKeyAction(keyData)
        }
    }

    private func handleKeyLongPress(_ keyData: KeyData) {
        // Check the key's long press behavior
        if let behavior = keyData.key.longPressBehavior {
            switch behavior {
            case .repeating:
                startKeyRepeat(for: keyData)
            case .alternates:
                // Alternates are handled by the gesture recognizer
                break
            }
        }
    }

    private func handleAlternateSelected(_ alternate: String, from keyData: KeyData) {
        // Handle smart punctuation for alternates
        if Key.shouldUnspacePunctuation(alternate) && maybePunctuating {
            textDocumentProxy.deleteBackward()
            let trailingSpace = Key.shouldAddTrailingSpaceAfterPunctuation(alternate) ? " " : ""
            textDocumentProxy.insertText(alternate + trailingSpace)
        } else {
            textDocumentProxy.insertText(alternate)
        }

        // Auto-unshift after inserting alternate
        autoUnshift()

        // Provide haptic feedback using the same system as regular key presses
        HapticFeedback.shared.keyPress(for: keyData.key, hasFullAccess: hasFullAccess)
    }

    private func handleKeyDoubleTap(_ keyData: KeyData) {
        guard let doubleTapBehavior = keyData.key.doubleTapBehavior else { return }

        switch doubleTapBehavior {
        case .capsLock:
            switch userShiftState {
            case .unshifted, .shifted:
                userShiftState = .capsLock
            case .capsLock:
                userShiftState = .unshifted
            }

            updateKeyboardForShiftChange()
        }
    }

    private func startKeyRepeat(for keyData: KeyData) {
        currentlyRepeatingKey = keyData

        // Perform the first repeat immediately
        performKeyAction(keyData)

        // Start the repeating timer
        keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: keyRepeatInterval, repeats: true) { [weak self] _ in
            self?.performKeyAction(keyData)
        }
    }

    private func stopKeyRepeat() {
        keyRepeatTimer?.invalidate()
        keyRepeatTimer = nil
        currentlyRepeatingKey = nil
    }

    private func performKeyAction(_ keyData: KeyData) {
        keyData.key.didTap(textDocumentProxy: textDocumentProxy,
                              suggestionService: suggestionService,
                              layerSwitchHandler: { [weak self] newLayer in
                                  self?.switchToLayer(newLayer)
                              },
                              layoutSwitchHandler: { [weak self] newLayout in
                                  self?.switchToLayout(newLayout)
                              },
                              shiftHandler: { [weak self] in
                                  self?.toggleShift()
                              },
                              autoUnshiftHandler: { [weak self] in
                                  self?.autoUnshift()
                              },
                              globeHandler: { [weak self] in
                                  self?.advanceToNextInputMode()
                              },
                              configurationHandler: { [weak self] config in
                                  self?.handleConfiguration(config)
                              },
                              maybePunctuating: maybePunctuating,
                              autocompleteWordDisabled: autocompleteWordDisabled,
                              toggleAutocompleteWord: { [weak self] in
                                  self?.toggleAutocompleteWord()
                              },
                              executeActions: { [weak self] actions in
                                  self?.executeActions(actions)
                              },
                              undoActions: undoActions,
                              clearUndo: { [weak self] in
                                  self?.clearUndo()
                              })

        // Provide haptic feedback for each repeat
        HapticFeedback.shared.keyPress(for: keyData.key, hasFullAccess: hasFullAccess)

        // Only reset maybePunctuating for keys that modify text content
        let shouldResetMaybePunctuating = keyData.key.shouldResetMaybePunctuating()
        if shouldResetMaybePunctuating {
            resetMaybePunctuating()
        }
        autoShift()
        refreshSuggestions()
    }

    private func effectiveShiftState() -> ShiftState {
        return userShiftOverride ? userShiftState : max(appShiftState, userShiftState)
    }

    private func toggleShift() {
        if userShiftState == .unshifted && appShiftState != .unshifted {
            // User is toggling override of app's capitalization preference
            userShiftOverride.toggle()
        } else {
            // Normal shift toggle behavior
            switch userShiftState {
            case .unshifted:
                userShiftState = .shifted
            case .shifted:
                userShiftState = .unshifted
            case .capsLock:
                userShiftState = .unshifted
            }
        }

        updateKeyboardForShiftChange()
    }

    private func autoUnshift() {
        switch userShiftState {
        case .unshifted:
            break
        case .shifted:
            userShiftState = .unshifted
            updateKeyboardForShiftChange()
        case .capsLock:
            // Caps lock should not auto-unshift
            break
        }

        // Always reset override after any key press that triggers auto-unshift
        userShiftOverride = false
    }

    private func autoShift() {
        let beforeInput = textDocumentProxy.documentContextBeforeInput ?? ""

        // Update app shift state based on host app's autocapitalization setting
        switch textDocumentProxy.autocapitalizationType {
        case .some(.none):
            appShiftState = .unshifted
        case .some(.words), .some(.sentences), .some(.allCharacters):
            if beforeInput.isEmpty {
                appShiftState = .shifted
            } else {
                switch textDocumentProxy.autocapitalizationType {
                case .some(.words):
                    // Capitalize after any whitespace
                    appShiftState = beforeInput.last?.isWhitespace == true ? .shifted : .unshifted
                case .some(.sentences):
                    // Capitalize at start and after sentence endings
                    let sentenceEnders = [". ", "! ", "? ", "\n"]
                    appShiftState = sentenceEnders.contains { beforeInput.hasSuffix($0) } ? .shifted : .unshifted
                case .some(.allCharacters):
                    appShiftState = .capsLock
                default:
                    appShiftState = .unshifted
                }
            }
        case .some(_):
            appShiftState = .unshifted
        case nil:
            appShiftState = .unshifted
        }

        updateKeyboardForShiftChange()
    }

    private func switchToLayer(_ layer: Layer) {
        currentLayer = layer
        rebuildKeyboard()
    }

    private func switchToLayout(_ layout: KeyboardLayout) {
        keyboardLayout = layout
        currentLayer = .alpha
        rebuildKeyboard()
    }

    private func setupDismissButton() {
        dismissButton = UIButton(type: .system)
        dismissButton.setTitle("", for: .normal)

        let theme = ColorTheme.current(for: traitCollection)
        dismissButton.tintColor = theme.decorationColor

        // Create downward chevron using SF Symbols
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: deviceLayout.editingButtonSize, weight: .light, scale: .default)
        let chevronImage = UIImage(systemName: "chevron.down", withConfiguration: chevronConfig)
        dismissButton.setImage(chevronImage, for: .normal)

        dismissButton.addTarget(self, action: #selector(handleDismissButton), for: .touchUpInside)

        UIView.performWithoutAnimation {
            view.addSubview(dismissButton)

            // Position the button appropriately for each layout
            let containerWidth = view.bounds.width
            let rightOffset = calculateDismissButtonOffset()
            let buttonX = containerWidth - rightOffset - dismissButtonSize
            let buttonY = (deviceLayout.topPadding - dismissButtonSize) / 2

            dismissButton.frame = CGRect(x: buttonX, y: buttonY, width: dismissButtonSize, height: dismissButtonSize)
        }
    }

    private func calculateDismissButtonOffset() -> CGFloat {
        let containerWidth = view.bounds.width
        let isShifted: Bool
        switch effectiveShiftState() {
        case .unshifted:
            isShifted = false
        case .shifted, .capsLock:
            isShifted = true
        }
        let firstRow = keyboardLayout.nodeRows(for: currentLayer, shifted: isShifted, layout: deviceLayout, needsGlobe: needsGlobe)[0]
        let rowWidth = Node.calculateRowWidth(for: firstRow)
        let rowStartX = (containerWidth - rowWidth) / 2

        // Find the rightmost key in the first row
        var rightmostKeyX: CGFloat = 0
        var rightmostKeyWidth: CGFloat = 0
        var xOffset = rowStartX

        for node in firstRow {
            switch node {
            case .key(_, let keyWidth):
                rightmostKeyX = xOffset
                rightmostKeyWidth = keyWidth
                xOffset += keyWidth
            case .gap(let gapWidth):
                xOffset += gapWidth
            case .split(let splitWidth):
                xOffset += splitWidth
            }
        }

        // Center the dismiss button above the rightmost key
        let rightmostKeyCenterX = rightmostKeyX + rightmostKeyWidth / 2
        return containerWidth - rightmostKeyCenterX - dismissButtonSize / 2
    }

    @objc private func handleDismissButton() {
        dismissKeyboard()
    }

    private func setupEditingButtons() {
        let theme = ColorTheme.current(for: traitCollection)
        let buttonConfig = UIImage.SymbolConfiguration(pointSize: deviceLayout.editingButtonSize, weight: .light, scale: .default)

        // Create cut button
        cutButton = UIButton(type: .system)
        cutButton.tintColor = theme.decorationColor
        let cutImage = UIImage(systemName: "scissors", withConfiguration: buttonConfig)
        cutButton.setImage(cutImage, for: .normal)
        cutButton.addTarget(self, action: #selector(handleCutButton), for: .touchUpInside)

        // Create copy button
        copyButton = UIButton(type: .system)
        copyButton.tintColor = theme.decorationColor
        let copyImage = UIImage(systemName: "doc.on.doc", withConfiguration: buttonConfig)
        copyButton.setImage(copyImage, for: .normal)
        copyButton.addTarget(self, action: #selector(handleCopyButton), for: .touchUpInside)

        // Create paste button
        pasteButton = UIButton(type: .system)
        pasteButton.tintColor = theme.decorationColor
        let pasteImage = UIImage(systemName: "doc.on.clipboard", withConfiguration: buttonConfig)
        pasteButton.setImage(pasteImage, for: .normal)
        pasteButton.addTarget(self, action: #selector(handlePasteButton), for: .touchUpInside)

        UIView.performWithoutAnimation {
            view.addSubview(cutButton)
            view.addSubview(copyButton)
            view.addSubview(pasteButton)

            // Calculate button positions explicitly
            let containerWidth = view.bounds.width
            let dismissRightOffset = calculateDismissButtonOffset()
            let buttonSpacing = deviceLayout.editingButtonSpacing
            let buttonY = (deviceLayout.topPadding - dismissButtonSize) / 2
            let buttonSize = dismissButtonSize

            // Paste button (leftmost of the three)
            let pasteX = containerWidth - (dismissRightOffset + buttonSize + buttonSpacing + buttonSize)
            pasteButton.frame = CGRect(x: pasteX, y: buttonY, width: buttonSize, height: buttonSize)

            // Copy button (middle)
            let copyX = pasteX - buttonSpacing - buttonSize
            copyButton.frame = CGRect(x: copyX, y: buttonY, width: buttonSize, height: buttonSize)

            // Cut button (leftmost)
            let cutX = copyX - buttonSpacing - buttonSize
            cutButton.frame = CGRect(x: cutX, y: buttonY, width: buttonSize, height: buttonSize)
        }
    }

    private func setupSuggestionView() {
        guard let suggestionService = SuggestionService() else {
            print("KeyboardViewController: Failed to initialize SuggestionService")
            return
        }
        self.suggestionService = suggestionService
        suggestionView = SuggestionView(deviceLayout: deviceLayout)


        suggestionService.delegate = suggestionView

        suggestionView.setOnTypeaheadTapped { [weak self] actions in
            self?.executeActions(actions)
            self?.autoShift()
            self?.refreshSuggestions()
        }

        suggestionView.setOnAutocorrectToggle { [weak self] in
            self?.toggleAutocompleteWord()
        }

        view.addSubview(suggestionView)

        // Position the suggestion view to use the full topPadding height
        let suggestionY: CGFloat = 0
        let suggestionHeight = deviceLayout.topPadding

        // Calculate available space for suggestions (left side of editing buttons)
        let containerWidth = view.bounds.width
        let dismissRightOffset = calculateDismissButtonOffset()
        let editingButtonsWidth = dismissButtonSize * 4 + deviceLayout.editingButtonSpacing * 3 // 4 buttons + 3 gaps

        // Align with the left edge of the first column of keys
        let isShifted: Bool
        switch effectiveShiftState() {
        case .unshifted:
            isShifted = false
        case .shifted, .capsLock:
            isShifted = true
        }
        let firstRow = keyboardLayout.nodeRows(for: currentLayer, shifted: isShifted, layout: deviceLayout, needsGlobe: needsGlobe)[0]
        let rowWidth = Node.calculateRowWidth(for: firstRow)
        let suggestionX = (containerWidth - rowWidth) / 2

        let availableWidth = containerWidth - dismissRightOffset - editingButtonsWidth - suggestionX - deviceLayout.suggestionGap

        suggestionView.frame = CGRect(x: suggestionX, y: suggestionY, width: availableWidth, height: suggestionHeight)
    }

    private func resetMaybePunctuating() {
        maybePunctuating = false
    }

    private func clearUndo() {
        undoActions = nil
        keyboardTouchView?.hasUndo = false
        keyboardTouchView?.setNeedsDisplay()
    }

    private func handleTextChange() {
        clearUndo()
        resetMaybePunctuating()
        autoShift()
        refreshSuggestions()
    }

    private func refreshSuggestions() {
        guard !pendingRefresh else { return }
        pendingRefresh = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingRefresh = false

            let before = self.textDocumentProxy.documentContextBeforeInput
            let after = self.textDocumentProxy.documentContextAfterInput
            let selected = self.textDocumentProxy.selectedText

            self.suggestionService.updateContext(before: before, after: after, selected: selected, autocorrectEnabled: !autocorrectAppDisabled && !autocorrectUserDisabled, shiftState: effectiveShiftState())
        }
    }

    private func executeActions(_ actions: [InputAction]) {
        var buildingUndoActions: [InputAction] = []

        buildingUndoActions.append(.maybePunctuating(maybePunctuating))

        for action in actions {
            switch action {
            case .insert(let text):
                for _ in 0..<text.count {
                    buildingUndoActions.append(.deleteBackward)
                }
                textDocumentProxy.insertText(text)
            case .moveCursor(let offset):
                buildingUndoActions.append(.moveCursor(-offset))
                if offset > 0 {
                    for _ in 0..<offset {
                        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
                    }
                } else if offset < 0 {
                    for _ in 0..<(-offset) {
                        textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
                    }
                }
            case .maybePunctuating(let value):
                // Don't add undo action here - we captured initial state above
                maybePunctuating = value
            case .deleteBackward:
                if let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty {
                    let deletedChar = String(before.last!)
                    buildingUndoActions.append(.insert(deletedChar))
                }
                textDocumentProxy.deleteBackward()
            }
        }

        undoActions = Array(buildingUndoActions.reversed())

        keyboardTouchView?.hasUndo = true
        keyboardTouchView?.setNeedsDisplay()
    }

    @objc private func handleCutButton() {
        // For cut: copy selected text then delete it
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
            textDocumentProxy.deleteBackward()
            handleTextChange()
        }
    }

    @objc private func handleCopyButton() {
        // Copy selected text to pasteboard
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
        }
    }

    @objc private func handlePasteButton() {
        // Paste text from pasteboard
        if let pasteText = UIPasteboard.general.string {
            textDocumentProxy.insertText(pasteText)
            handleTextChange()
        }
    }

    private func updateKeyboardForShiftChange() {
        let effectiveShiftState = effectiveShiftState()

        // Only update if the effective shift state has actually changed
        if keyboardTouchView.shiftState == effectiveShiftState {
            return
        }

        // Update display state and key data - gesture recognizer persists now
        keyboardTouchView.shiftState = effectiveShiftState
        keyboardTouchView.autocorrectEnabled = !autocorrectUserDisabled
        keyboardTouchView.hasUndo = undoActions != nil
        keyboardTouchView.keyData = createKeyData()
        keyboardTouchView.setNeedsDisplay()
    }

    private func rebuildKeyboard() {
        stopKeyRepeat()
        UIView.performWithoutAnimation {
            view.subviews.forEach { $0.removeFromSuperview() }
            keyPopouts.removeAll()
            setupKeyboard()
        }
    }

    private func showKeyPopout(for keyData: KeyData) {
        let popout = KeyPopoutView.createPopout(for: keyData, shiftState: effectiveShiftState(), containerView: view, traitCollection: traitCollection, deviceLayout: deviceLayout)
        view.addSubview(popout)
        keyPopouts[keyData.index] = popout
    }

    private func showAlternatesPopup(for keyData: KeyData, alternates: [String]) {
        // Hide any existing popout for this key
        hideKeyPopout(for: keyData)

        // Show the alternates popup via the touch view
        keyboardTouchView.showAlternatesPopup(for: keyData, alternates: alternates)
    }

    private func hideKeyPopout(for keyData: KeyData) {
        guard let popout = keyPopouts[keyData.index] else { return }
        popout.removeFromSuperview()
        keyPopouts.removeValue(forKey: keyData.index)
    }



    // MARK: - UITextInputDelegate

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAutocorrectSettings()
        handleTextChange()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        handleTextChange()
    }

    // MARK: - Autocorrect Detection

    private func updateAutocorrectSettings() {
        // Check the host app's autocorrect setting
        let hostDisablesAutocorrect = (textDocumentProxy.autocorrectionType == .no)

        // Disable autocorrect if the host app explicitly disables it
        // This covers SSH apps, password fields, code editors, and other contexts where text correction is unwanted
        if hostDisablesAutocorrect {
            disableAutocorrect()
        } else {
            // Regular text input contexts where autocorrect is welcome
            enableAutocorrect()
        }
    }

    private func disableAutocorrect() {
        autocorrectAppDisabled = true
        refreshSuggestions()
    }

    private func enableAutocorrect() {
        autocorrectAppDisabled = false
        refreshSuggestions()
    }

    func toggleAutocompleteWord() {
        autocompleteWordDisabled.toggle()
        suggestionView.setAutocompleteWordDisabled(autocompleteWordDisabled)
    }

    private func handleConfiguration(_ config: Configuration) {
        switch config {
        case .toggleAutocorrect:
            autocorrectUserDisabled.toggle()
            keyboardTouchView?.autocorrectEnabled = !autocorrectUserDisabled
            keyboardTouchView?.setNeedsDisplay()
            refreshSuggestions()
        }
    }
}

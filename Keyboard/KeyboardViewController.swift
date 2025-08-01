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
    private var currentShiftState: ShiftState = .unshifted
    private var keyboardTouchView: KeyboardTouchView!
    private var deviceLayout: DeviceLayout!
    private var heightConstraint: NSLayoutConstraint?
    private var keyboardLayout: KeyboardLayout = .canary
    private var needsGlobe: Bool = false
    private var keyPopouts: [Int: UIView] = [:]
    private var dismissButton: UIButton!

    // Key repeat support
    private var keyRepeatTimer: Timer?
    private var currentlyRepeatingKey: KeyData?
    private let keyRepeatInitialDelay: TimeInterval = 0.5
    private let keyRepeatInterval: TimeInterval = 0.05

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        needsGlobe = needsInputModeSwitchKey
        setupKeyboard()
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
        keyboardTouchView.currentShiftState = currentShiftState
        keyboardTouchView.deviceLayout = deviceLayout
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

        keyboardTouchView.onShiftDoubleTap = { [weak self] keyData in
            self?.handleShiftDoubleTap(keyData)
        }

        // Calculate keyboard height first
        let isShifted: Bool
        switch currentShiftState {
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
                item: view,
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
        }
    }

    private func createKeyData() -> [KeyData] {
        var keys: [KeyData] = []
        var yOffset: CGFloat = deviceLayout.topPadding

        let isShifted: Bool
        switch currentShiftState {
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
            case .key(let keyType, let keyWidth):
                let frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: deviceLayout.keyHeight)
                let isLargeScreen = view.bounds.width > largeScreenWidth
                let keyData = KeyData(
                    index: startingIndex + keys.count,
                    keyType: keyType,
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
        HapticFeedback.shared.keyPress(for: keyData.keyType, hasFullAccess: hasFullAccess)

        let isLargeScreen = view.bounds.width > largeScreenWidth
        if case .simple = keyData.keyType, !isLargeScreen {
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
            keyData.keyType.didTap(textDocumentProxy: textDocumentProxy,
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
                                  })
        }
    }

    private func handleKeyLongPress(_ keyData: KeyData) {
        // Only start key repeat for backspace
        if case .backspace = keyData.keyType {
            startKeyRepeat(for: keyData)
        }
    }

    private func handleShiftDoubleTap(_ keyData: KeyData) {
        switch currentShiftState {
        case .unshifted, .shifted:
            currentShiftState = .capsLock
        case .capsLock:
            currentShiftState = .unshifted
        }

        updateKeyboardForShiftChange()
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
        keyData.keyType.didTap(textDocumentProxy: textDocumentProxy,
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
                              })

        // Provide haptic feedback for each repeat
        HapticFeedback.shared.keyPress(for: keyData.keyType, hasFullAccess: hasFullAccess)
    }

    private func toggleShift() {
        switch currentShiftState {
        case .unshifted:
            currentShiftState = .shifted
        case .shifted:
            currentShiftState = .unshifted
        case .capsLock:
            currentShiftState = .unshifted
        }

        updateKeyboardForShiftChange()
    }

    private func autoUnshift() {
        switch currentShiftState {
        case .unshifted:
            break
        case .shifted:
            currentShiftState = .unshifted
            updateKeyboardForShiftChange()
        case .capsLock:
            // Caps lock should not auto-unshift
            break
        }
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
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: deviceLayout.chevronSize, weight: .light, scale: .default)
        let chevronImage = UIImage(systemName: "chevron.down", withConfiguration: chevronConfig)
        dismissButton.setImage(chevronImage, for: .normal)

        dismissButton.addTarget(self, action: #selector(handleDismissButton), for: .touchUpInside)

        UIView.performWithoutAnimation {
            view.addSubview(dismissButton)
            dismissButton.translatesAutoresizingMaskIntoConstraints = false

            // Position the button appropriately for each layout
            let rightOffset = calculateDismissButtonOffset()

            NSLayoutConstraint.activate([
                dismissButton.widthAnchor.constraint(equalToConstant: dismissButtonSize),
                dismissButton.heightAnchor.constraint(equalToConstant: dismissButtonSize),
                dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -rightOffset),
                dismissButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 12)
            ])
        }
    }

    private func calculateDismissButtonOffset() -> CGFloat {
        let containerWidth = view.bounds.width
        let isShifted: Bool
        switch currentShiftState {
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

    private func updateKeyboardForShiftChange() {
        // Update display state and key data - gesture recognizer persists now
        keyboardTouchView.currentShiftState = currentShiftState
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
        let popout = KeyPopoutView.createPopout(for: keyData, shiftState: currentShiftState, containerView: view, traitCollection: traitCollection)
        view.addSubview(popout)
        keyPopouts[keyData.index] = popout
    }

    private func hideKeyPopout(for keyData: KeyData) {
        guard let popout = keyPopouts[keyData.index] else { return }
        popout.removeFromSuperview()
        keyPopouts.removeValue(forKey: keyData.index)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            keyboardTouchView?.setNeedsDisplay()
        }
    }
}

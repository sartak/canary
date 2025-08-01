//
//  KeyboardTouchView.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let largeScreenWidth: CGFloat = 600

class KeyboardTouchView: UIView, UIGestureRecognizerDelegate {
    var keyData: [KeyData] = [] {
        didSet {
            gestureRecognizer?.keyData = keyData
        }
    }
    var currentShiftState: ShiftState = .unshifted
    var deviceLayout: DeviceLayout!
    var keysWithPopouts: Set<Int> = []
    var onKeyTouchDown: ((KeyData) -> Void)? {
        didSet {
            gestureRecognizer?.onKeyTouchDown = onKeyTouchDown
        }
    }
    var onKeyTouchUp: ((KeyData) -> Void)? {
        didSet {
            gestureRecognizer?.onKeyTouchUp = onKeyTouchUp
        }
    }
    var onKeyLongPress: ((KeyData) -> Void)? {
        didSet {
            gestureRecognizer?.onKeyLongPress = onKeyLongPress
        }
    }
    var onShiftDoubleTap: ((KeyData) -> Void)?

    // Multi-touch gesture recognizer
    private(set) var gestureRecognizer: MultiTouchKeyboardGestureRecognizer!

    // Double-tap gesture recognizer for shift key
    private var shiftDoubleTapRecognizer: UITapGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTouchHandling()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTouchHandling()
    }

    private func setupTouchHandling() {
        // Enable multi-touch support
        isMultipleTouchEnabled = true

        // Create and configure gesture recognizer
        gestureRecognizer = MultiTouchKeyboardGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        gestureRecognizer.delegate = self
        addGestureRecognizer(gestureRecognizer)

        // Create double-tap recognizer once
        setupShiftDoubleTapGestureRecognizer()
    }

    @objc private func handleGesture(_ recognizer: MultiTouchKeyboardGestureRecognizer) {
        // The gesture recognizer handles all touch logic through callbacks
        // This method exists to satisfy the target-action pattern but doesn't need implementation
    }

    private func setupShiftDoubleTapGestureRecognizer() {
        // Create double-tap recognizer for shift key once
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleShiftDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        doubleTapRecognizer.delegate = self

        // Make the multi-touch recognizer wait for double-tap to fail
        gestureRecognizer.require(toFail: doubleTapRecognizer)

        addGestureRecognizer(doubleTapRecognizer)
        shiftDoubleTapRecognizer = doubleTapRecognizer
    }

    @objc private func handleShiftDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)

        // Find which key was double-tapped
        guard let tappedKey = keyData.first(where: { $0.frame.contains(location) }) else {
            return
        }

        // Verify it's the shift key
        if case .shift = tappedKey.keyType {
            onShiftDoubleTap?(tappedKey)
        }
    }


    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous recognition between tap gestures and multi-touch gestures
        // This prevents conflicts between single-tap and double-tap detection
        if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is MultiTouchKeyboardGestureRecognizer {
            return false
        }
        if gestureRecognizer is MultiTouchKeyboardGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer {
            return false
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: self)

        if gestureRecognizer is UITapGestureRecognizer {
            // Only allow double-tap recognizer to receive touches on the shift key
            return keyData.contains { keyData in
                if case .shift = keyData.keyType {
                    return keyData.frame.contains(location)
                }
                return false
            }
        }

        return true
    }



    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let isLargeScreen = bounds.width > largeScreenWidth

        let theme = ColorTheme.current(for: self.traitCollection)

        for key in keyData {
            let isPressed = gestureRecognizer.pressedKeyIndices.contains(key.index)

            // Draw key shadow (only for visible keys, not when pressed)
            if !isPressed && key.keyType != .empty {
                let shadowPath = UIBezierPath(roundedRect: key.frame, cornerRadius: deviceLayout.cornerRadius)
                let context = UIGraphicsGetCurrentContext()
                context?.saveGState()
                context?.setShadow(offset: theme.keyShadowOffset, blur: theme.keyShadowRadius, color: theme.keyShadowColor.cgColor)
                theme.keyShadowColor.setFill()
                shadowPath.fill()
                context?.restoreGState()
            }

            // Draw rounded key background
            let path = UIBezierPath(roundedRect: key.frame, cornerRadius: deviceLayout.cornerRadius)
            let color = if isPressed {
                key.keyType.tappedBackgroundColor(shiftState: currentShiftState, isLargeScreen: isLargeScreen, traitCollection: self.traitCollection)
            } else {
                key.keyType.backgroundColor(shiftState: currentShiftState, traitCollection: self.traitCollection)
            }
            color.setFill()
            path.fill()

            // Draw key content (hide if this key has a popout showing)
            let shouldHideContent = keysWithPopouts.contains(key.index)
            if !shouldHideContent {
                // Check if key should use SF Symbol
                if let symbolName = key.keyType.sfSymbolName(shiftState: currentShiftState, pressed: isPressed) {
                    let fontSize = key.keyType.fontSize(deviceLayout: deviceLayout)
                    let symbolConfig = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .light)
                    if let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig) {
                        // Draw SF Symbol
                        let imageSize = symbolImage.size
                        let imageRect = CGRect(
                            x: key.frame.midX - imageSize.width / 2,
                            y: key.frame.midY - imageSize.height / 2,
                            width: imageSize.width,
                            height: imageSize.height
                        )

                        // Tint the symbol with the text color
                        symbolImage.withTintColor(theme.textColor, renderingMode: .alwaysOriginal).draw(in: imageRect)
                    } else {
                        // Fallback to text if SF Symbol fails to load
                        drawKeyText(for: key, theme: theme)
                    }
                } else {
                    // Draw regular text
                    drawKeyText(for: key, theme: theme)
                }
            }
        }
    }

    private func drawKeyText(for key: KeyData, theme: ColorTheme) {
        let text = key.keyType.label(shiftState: currentShiftState)
        if !text.isEmpty {
            let fontSize = key.keyType.fontSize(deviceLayout: deviceLayout)
            let font = UIFont.systemFont(ofSize: fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: theme.textColor
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: key.frame.midX - textSize.width / 2,
                y: key.frame.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

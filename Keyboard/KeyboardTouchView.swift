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
    var currentShifted: Bool = false
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

    // Multi-touch gesture recognizer
    private var gestureRecognizer: MultiTouchKeyboardGestureRecognizer!

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
    }

    @objc private func handleGesture(_ recognizer: MultiTouchKeyboardGestureRecognizer) {
        // The gesture recognizer handles all touch logic through callbacks
        // This method exists to satisfy the target-action pattern but doesn't need implementation
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our custom gesture recognizer to work simultaneously with other recognizers
        return gestureRecognizer is MultiTouchKeyboardGestureRecognizer
    }



    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let isLargeScreen = bounds.width > largeScreenWidth

        let theme = ColorTheme.current(for: self.traitCollection)

        for key in keyData {
            let isPressed = gestureRecognizer.pressedKeyIndices.contains(key.index)

            // Draw key shadow (only for visible keys, not when pressed)
            if !isPressed && key.keyType != .empty {
                let shadowPath = UIBezierPath(roundedRect: key.frame, cornerRadius: 5)
                let context = UIGraphicsGetCurrentContext()
                context?.saveGState()
                context?.setShadow(offset: theme.keyShadowOffset, blur: theme.keyShadowRadius, color: theme.keyShadowColor.cgColor)
                theme.keyShadowColor.setFill()
                shadowPath.fill()
                context?.restoreGState()
            }

            // Draw rounded key background
            let path = UIBezierPath(roundedRect: key.frame, cornerRadius: 5)
            let color = if isPressed {
                key.keyType.tappedBackgroundColor(shifted: currentShifted, isLargeScreen: isLargeScreen, traitCollection: self.traitCollection)
            } else {
                key.keyType.backgroundColor(shifted: currentShifted, traitCollection: self.traitCollection)
            }
            color.setFill()
            path.fill()

            // Draw key content (hide if this key has a popout showing)
            let shouldHideContent = keysWithPopouts.contains(key.index)
            if !shouldHideContent {
                // Check if key should use SF Symbol
                if let symbolName = key.keyType.sfSymbolName(shifted: currentShifted, pressed: isPressed) {
                    let fontSize = key.keyType.fontSize()
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
        let text = key.keyType.label(shifted: currentShifted)
        if !text.isEmpty {
            let fontSize = key.keyType.fontSize()
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

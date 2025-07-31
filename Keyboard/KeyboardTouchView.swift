//
//  KeyboardTouchView.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let largeScreenWidth: CGFloat = 600

class KeyboardTouchView: UIView {
    var keyData: [KeyData] = []
    var currentShifted: Bool = false
    var keysWithPopouts: Set<Int> = []
    var onKeyTouchDown: ((KeyData) -> Void)?
    var onKeyTouchUp: ((KeyData) -> Void)?

    // Multi-touch support
    private var touchQueue: [(UITouch, KeyData)] = []
    private var pressedKeys: Set<Int> = []

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

        // Disable system gesture recognizer delays that cause edge touch issues
        DispatchQueue.main.async { [weak self] in
            self?.disableSystemGestureDelays()
        }
    }

    private func disableSystemGestureDelays() {
        // Find the window and disable delaysTouchesBegan on system gesture recognizers
        guard let window = self.superview?.window ?? self.window else {
            // If we don't have a window yet, try again later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.disableSystemGestureDelays()
            }
            return
        }

        if let gestureRecognizers = window.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if recognizer.delaysTouchesBegan {
                    recognizer.delaysTouchesBegan = false
                }
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)

            if let key = keyData.first(where: { $0.frame.contains(location) }) {
                touchQueue.append((touch, key))
                pressedKeys.insert(key.index)
                onKeyTouchDown?(key)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            processQueueUpToTouch(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            processQueueUpToTouch(touch)
        }
    }

    private func processQueueUpToTouch(_ endingTouch: UITouch) {
        guard let endingTouchIndex = touchQueue.firstIndex(where: { $0.0 === endingTouch }) else { return }

        // Process all touches up to and including the ending touch, in order
        let touchesToProcess = Array(touchQueue[0...endingTouchIndex])

        for (touch, key) in touchesToProcess {
            onKeyTouchUp?(key)
            pressedKeys.remove(key.index)
        }

        // Remove processed touches from queue
        touchQueue.removeFirst(touchesToProcess.count)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let isLargeScreen = bounds.width > largeScreenWidth

        for key in keyData {
            // Draw rounded key background
            let path = UIBezierPath(roundedRect: key.frame, cornerRadius: 5)
            let isPressed = pressedKeys.contains(key.index)
            let color = if isPressed {
                key.keyType.tappedBackgroundColor(shifted: currentShifted, isLargeScreen: isLargeScreen)
            } else {
                key.keyType.backgroundColor(shifted: currentShifted)
            }
            color.setFill()
            path.fill()

            // Draw key text (hide text if this key has a popout showing)
            let shouldHideText = keysWithPopouts.contains(key.index)
            if !shouldHideText {
                let text = key.keyType.label(shifted: currentShifted)
                if !text.isEmpty {
                    let fontSize = key.keyType.fontSize()
                    let font = UIFont.systemFont(ofSize: fontSize)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: UIColor.white
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
    }
}
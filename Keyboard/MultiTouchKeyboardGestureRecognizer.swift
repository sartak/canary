//
//  MultiTouchKeyboardGestureRecognizer.swift
//  Keyboard
//
//  Created by Claude on 7/31/25.
//

import UIKit

class MultiTouchKeyboardGestureRecognizer: UIGestureRecognizer {
    var keyData: [KeyData] = []
    var onKeyTouchDown: ((KeyData) -> Void)?
    var onKeyTouchUp: ((KeyData) -> Void)?
    var onKeyLongPress: ((KeyData) -> Void)?
    var onAlternatesShow: ((KeyData, [String]) -> Void)?
    var onAlternatesMove: ((CGPoint) -> Void)?
    var onAlternatesSelect: (() -> Void)?
    var onAlternatesDismiss: (() -> Void)?

    // Multi-touch support - same as original implementation
    private var touchQueue: [(UITouch, KeyData)] = []
    private var pressedKeys: Set<Int> = []

    // Long press support
    private var longPressTimers: [UITouch: Timer] = [:]
    private var longPressTriggered: Set<UITouch> = []
    private let longPressDelay: TimeInterval = 0.5

    // Alternates support
    private var alternatesActiveTouch: UITouch? = nil
    private var alternatesActiveKey: KeyData? = nil

    var pressedKeyIndices: Set<Int> {
        return pressedKeys
    }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        setupGestureRecognizer()
    }

    private func setupGestureRecognizer() {
        // Don't cancel touches in view - we want to handle them
        cancelsTouchesInView = false
        delaysTouchesEnded = false
        delaysTouchesBegan = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        for touch in touches {
            // Ignore new touches while alternates are active
            if alternatesActiveTouch != nil {
                continue
            }

            let location = touch.location(in: view)

            if let key = keyData.first(where: { $0.frame.contains(location) }) {
                touchQueue.append((touch, key))
                pressedKeys.insert(key.index)
                onKeyTouchDown?(key)

                // Start long press timer
                startLongPressTimer(for: touch, key: key)
            }
        }

        // Always succeed for gesture recognition
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        // Handle alternates movement
        if let activeTouch = alternatesActiveTouch, touches.contains(activeTouch) {
            let location = activeTouch.location(in: view)
            onAlternatesMove?(location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        for touch in touches {
            // Handle alternates selection
            if touch == alternatesActiveTouch {
                onAlternatesSelect?()
                alternatesActiveTouch = nil
                alternatesActiveKey = nil
                // Remove this touch from the queue since it was consumed by alternates selection
                if let touchIndex = touchQueue.firstIndex(where: { $0.0 === touch }) {
                    let (_, key) = touchQueue.remove(at: touchIndex)
                    pressedKeys.remove(key.index)
                }
            } else {
                cancelLongPressTimer(for: touch)
                processQueueUpToTouch(touch)
            }
        }

        // Update gesture state based on remaining touches
        if touchQueue.isEmpty {
            state = .ended
        } else {
            state = .changed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)

        for touch in touches {
            // Handle alternates cancellation
            if touch == alternatesActiveTouch {
                onAlternatesDismiss?()
                alternatesActiveTouch = nil
                alternatesActiveKey = nil
            } else {
                cancelLongPressTimer(for: touch)
                processQueueUpToTouch(touch)
            }
        }

        // Update gesture state
        if touchQueue.isEmpty {
            state = .cancelled
        } else {
            state = .changed
        }
    }

    private func processQueueUpToTouch(_ endingTouch: UITouch) {
        guard let endingTouchIndex = touchQueue.firstIndex(where: { $0.0 === endingTouch }) else { return }

        // Process all touches up to and including the ending touch, in order
        let touchesToProcess = Array(touchQueue[0...endingTouchIndex])

        for (_, key) in touchesToProcess {
            onKeyTouchUp?(key)
            pressedKeys.remove(key.index)
        }

        // Remove processed touches from queue
        touchQueue.removeFirst(touchesToProcess.count)
    }

    override func reset() {
        super.reset()
        touchQueue.removeAll()
        pressedKeys.removeAll()
        cancelAllLongPressTimers()

        // Clear alternates state
        if alternatesActiveTouch != nil {
            onAlternatesDismiss?()
            alternatesActiveTouch = nil
            alternatesActiveKey = nil
        }
    }

    // MARK: - Long Press Support

    private func startLongPressTimer(for touch: UITouch, key: KeyData) {
        let timer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
            self?.handleLongPress(for: touch, key: key)
        }
        longPressTimers[touch] = timer
    }

    private func cancelLongPressTimer(for touch: UITouch) {
        longPressTimers[touch]?.invalidate()
        longPressTimers.removeValue(forKey: touch)
        longPressTriggered.remove(touch)
    }

    private func cancelAllLongPressTimers() {
        for timer in longPressTimers.values {
            timer.invalidate()
        }
        longPressTimers.removeAll()
        longPressTriggered.removeAll()
    }

    private func handleLongPress(for touch: UITouch, key: KeyData) {
        longPressTriggered.insert(touch)

        // Check if key has alternates
        if case .alternates(let alternates) = key.key.longPressBehavior {
            // Add the original key character to the alternates list
            var alternatesWithOriginal = alternates
            if case .simple(let originalChar) = key.key.keyType {
                alternatesWithOriginal.insert(originalChar, at: 0) // Put original first
            }

            // Show alternates popup
            alternatesActiveTouch = touch
            alternatesActiveKey = key
            onAlternatesShow?(key, alternatesWithOriginal)
        } else {
            // Regular long press behavior
            onKeyLongPress?(key)
        }
    }
}

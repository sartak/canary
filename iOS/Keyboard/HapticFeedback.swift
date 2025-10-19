//
//  HapticFeedback.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit
import AudioToolbox

class HapticFeedback {
    private let subtleImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    static let shared = HapticFeedback()

    private var isAvailable: Bool {
        // Check if haptic feedback is available on this device
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    private init() {
        // Note: Don't prepare impact generators here since they require full access
        // We'll prepare them only when hasFullAccess is true
    }

    func keyPress(for key: Key, hasFullAccess: Bool) {
        guard KeyboardPreferences.shared.hapticFeedbackEnabled else { return }

        if hasFullAccess && isAvailable {
            useRichHapticFeedback(for: key)
        } else {
            useSystemSoundFeedback(for: key)
        }
    }

    private func useRichHapticFeedback(for key: Key) {
        // Prepare generators for better performance
        subtleImpact.prepare()
        lightImpact.prepare()
        selectionFeedback.prepare()

        switch key.feedbackPattern() {
        case .subtle:
            subtleImpact.impactOccurred()
        case .light:
            lightImpact.impactOccurred()
        case .selection:
            selectionFeedback.selectionChanged()
        case .none:
            break
        }
    }

    private func useSystemSoundFeedback(for key: Key) {
        switch key.feedbackPattern() {
        case .subtle, .light:
            // Standard keyboard click sound
            AudioServicesPlaySystemSound(1104) // kSystemSoundID_Keyboard
        case .selection:
            // Different sound for delete actions
            AudioServicesPlaySystemSound(1155) // kSystemSoundID_DeleteKey
        case .none:
            // No sound for empty keys
            break
        }
    }
}

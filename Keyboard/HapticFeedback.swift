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

    func keyPress(for keyType: KeyType, hasFullAccess: Bool) {
        guard KeyboardPreferences.shared.hapticFeedbackEnabled else { return }

        if hasFullAccess && isAvailable {
            useRichHapticFeedback(for: keyType)
        } else {
            useSystemSoundFeedback(for: keyType)
        }
    }

    private func useRichHapticFeedback(for keyType: KeyType) {
        // Prepare generators for better performance
        subtleImpact.prepare()
        lightImpact.prepare()
        selectionFeedback.prepare()

        switch keyType {
        case .simple:
            // Very subtle haptic for regular character keys
            subtleImpact.impactOccurred()
        case .space, .enter:
            // Light haptic for important action keys (reduced from medium)
            lightImpact.impactOccurred()
        case .backspace:
            // Selection haptic for delete actions
            selectionFeedback.selectionChanged()
        case .shift, .layerSwitch, .layoutSwitch:
            // Very subtle haptic for modifier keys
            subtleImpact.impactOccurred()
        case .globe:
            // No haptic for globe to reduce overall feedback
            break
        case .empty:
            // No haptic for empty keys
            break
        }
    }

    private func useSystemSoundFeedback(for keyType: KeyType) {
        switch keyType {
        case .simple, .space, .enter, .shift, .layerSwitch, .layoutSwitch:
            // Standard keyboard click sound
            AudioServicesPlaySystemSound(1104) // kSystemSoundID_Keyboard
        case .backspace, .globe:
            // Different sound for delete actions
            AudioServicesPlaySystemSound(1155) // kSystemSoundID_DeleteKey
        case .empty:
            // No sound for empty keys
            break
        }
    }
}

//
//  KeyboardPreferences.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import Foundation

class KeyboardPreferences {
    static let shared = KeyboardPreferences()

    private let userDefaults = UserDefaults.standard

    private init() {}

    // Haptic feedback preference
    var hapticFeedbackEnabled: Bool {
        get {
            // Default to false for now - will be user configurable later
            return userDefaults.object(forKey: "hapticFeedbackEnabled") as? Bool ?? false
        }
        set {
            userDefaults.set(newValue, forKey: "hapticFeedbackEnabled")
        }
    }
}

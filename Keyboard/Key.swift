//
//  Key.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

enum ShiftState: Equatable {
    case unshifted
    case shifted
    case capsLock
}

enum RepeatingBehavior: Equatable {
    case repeating
}

enum DoubleTapBehavior: Equatable {
    case capsLock
}

enum FeedbackPattern: Equatable {
    case subtle
    case light
    case selection
    case none
}

enum KeyType: Equatable {
    case simple(String)
    case backspace
    case shift
    case enter
    case space
    case layerSwitch(Layer)
    case layoutSwitch(KeyboardLayout)
    case globe
    case empty
}

struct Key {
    let keyType: KeyType
    let longPressBehavior: RepeatingBehavior?
    let doubleTapBehavior: DoubleTapBehavior?

    init(_ keyType: KeyType, longPressBehavior: RepeatingBehavior? = nil, doubleTapBehavior: DoubleTapBehavior? = nil) {
        self.keyType = keyType
        self.longPressBehavior = longPressBehavior
        self.doubleTapBehavior = doubleTapBehavior
    }

    func didTap(textDocumentProxy: UITextDocumentProxy, layerSwitchHandler: @escaping (Layer) -> Void, layoutSwitchHandler: @escaping (KeyboardLayout) -> Void, shiftHandler: @escaping () -> Void, autoUnshiftHandler: @escaping () -> Void, globeHandler: @escaping () -> Void) {
        // Handle the key action
        switch keyType {
        case .simple(let text):
            textDocumentProxy.insertText(text)
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .shift:
            shiftHandler()
        case .enter:
            textDocumentProxy.insertText("\n")
        case .space:
            textDocumentProxy.insertText(" ")
        case .layerSwitch(let layer):
            layerSwitchHandler(layer)
        case .layoutSwitch(let layout):
            layoutSwitchHandler(layout)
        case .globe:
            globeHandler()
        case .empty:
            // Do nothing for empty keys
            break
        }

        // Handle auto-unshift for all keys except shift
        switch keyType {
        case .shift:
            break
        case .simple, .backspace, .enter, .space, .layerSwitch, .layoutSwitch, .globe:
            autoUnshiftHandler()
        case .empty:
            break
        }
    }

    func sfSymbolName(shiftState: ShiftState = .unshifted, pressed: Bool = false) -> String? {
        switch keyType {
        case .globe:
            return "globe"
        case .shift:
            switch shiftState {
            case .unshifted:
                return "shift"
            case .shifted:
                return "shift.fill"
            case .capsLock:
                return "capslock.fill"
            }
        case .backspace:
            return pressed ? "delete.backward.fill" : "delete.backward"
        default:
            return nil
        }
    }

    func label(shiftState: ShiftState) -> String {
        switch keyType {
        case .simple(let text):
            return text
        case .backspace:
            return "⌫" // Fallback if SF Symbol rendering fails
        case .shift:
            switch shiftState {
            case .unshifted:
                return "⇧" // Fallback if SF Symbol rendering fails
            case .shifted:
                return "⬆︎" // Fallback if SF Symbol rendering fails
            case .capsLock:
                return "⇪" // Fallback if SF Symbol rendering fails
            }
        case .enter:
            return "↩︎"
        case .space:
            return ""
        case .layerSwitch(let layer):
            switch layer {
            case .symbol:
                return "λ"
            case .number:
                return "#"
            case .alpha:
                return "ABC"
            }
        case .layoutSwitch(let layout):
            switch layout {
            case .canary:
                return "CAN"
            case .qwerty:
                return "QWE"
            }
        case .globe:
            return "◉" // Fallback if SF Symbol rendering fails
        case .empty:
            return ""
        }
    }

    func fontSize() -> CGFloat {
        switch keyType {
        case .simple, .space, .empty:
            return 22
        case .backspace, .shift, .enter:
            return 16
        case .globe:
            return 12
        case .layerSwitch:
            let labelText = self.label(shiftState: .unshifted)
            return labelText.count > 1 ? 12 : 16
        case .layoutSwitch:
            return 12
        }
    }

    func fontSize(deviceLayout: DeviceLayout) -> CGFloat {
        switch keyType {
        case .simple, .space, .empty:
            return deviceLayout.regularFontSize
        case .backspace, .shift, .enter:
            return deviceLayout.specialFontSize
        case .globe:
            return deviceLayout.smallFontSize
        case .layerSwitch:
            let labelText = self.label(shiftState: .unshifted)
            return labelText.count > 1 ? deviceLayout.smallFontSize : deviceLayout.specialFontSize
        case .layoutSwitch:
            return deviceLayout.smallFontSize
        }
    }

    func backgroundColor(shiftState: ShiftState, traitCollection: UITraitCollection, tapped: Bool = false, isLargeScreen: Bool = false) -> UIColor {
        let theme = ColorTheme.current(for: traitCollection)

        switch keyType {
        case .simple:
            return tapped ? (isLargeScreen ? theme.secondaryKeyColor : theme.primaryKeyColor) : theme.primaryKeyColor
        case .space:
            return tapped ? theme.secondaryKeyColor : theme.primaryKeyColor
        case .shift:
            switch shiftState {
            case .unshifted:
                return tapped ? theme.primaryKeyColor : theme.secondaryKeyColor
            case .shifted, .capsLock:
                return tapped ? theme.secondaryKeyColor : theme.primaryKeyColor
            }
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return tapped ? theme.primaryKeyColor : theme.secondaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func feedbackPattern() -> FeedbackPattern {
        switch keyType {
        case .simple, .shift, .layerSwitch, .layoutSwitch:
            return .subtle
        case .space, .enter:
            return .light
        case .backspace:
            return .selection
        case .globe, .empty:
            return .none
        }
    }
}

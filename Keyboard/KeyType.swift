//
//  KeyType.swift
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

enum Layer: Equatable {
    case alpha
    case symbol
    case number
}

enum Node {
    case key(KeyType, CGFloat)
    case gap(CGFloat)
    case split(CGFloat)

    static func calculateRowWidth(for row: [Node]) -> CGFloat {
        return row.reduce(0) { total, node in
            switch node {
            case .key(_, let width): return total + width
            case .gap(let width): return total + width
            case .split(let width): return total + width
            }
        }
    }
}

struct KeyData {
    let index: Int
    let keyType: KeyType
    let frame: CGRect
}

enum KeyType: Equatable {
    case simple(Character)
    case backspace
    case shift
    case enter
    case space
    case layerSwitch(Layer)
    case layoutSwitch(KeyboardLayout)
    case globe
    case empty

    func backgroundColor(shiftState: ShiftState, traitCollection: UITraitCollection) -> UIColor {
        let theme = ColorTheme.current(for: traitCollection)
        switch self {
        case .simple, .space:
            return theme.primaryKeyColor
        case .shift:
            switch shiftState {
            case .unshifted:
                return theme.secondaryKeyColor
            case .shifted, .capsLock:
                return theme.primaryKeyColor
            }
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return theme.secondaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func tappedBackgroundColor(shiftState: ShiftState, isLargeScreen: Bool, traitCollection: UITraitCollection) -> UIColor {
        let theme = ColorTheme.current(for: traitCollection)
        switch self {
        case .simple:
            return isLargeScreen ? theme.secondaryKeyColor : theme.primaryKeyColor
        case .space:
            return theme.secondaryKeyColor
        case .shift:
            switch shiftState {
            case .unshifted:
                return theme.primaryKeyColor
            case .shifted, .capsLock:
                return theme.secondaryKeyColor
            }
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return theme.primaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func sfSymbolName(shiftState: ShiftState = .unshifted, pressed: Bool = false) -> String? {
        switch self {
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
        switch self {
        case .simple(let char):
            return String(char)
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
        switch self {
        case .simple, .space, .empty:
            return 22
        case .backspace, .shift, .enter:
            return 16
        case .globe:
            return 12
        case .layerSwitch:
            let labelLength = self.label(shiftState: .unshifted).count
            return labelLength > 1 ? 12 : 16
        case .layoutSwitch:
            return 12
        }
    }

    func fontSize(deviceLayout: DeviceLayout) -> CGFloat {
        switch self {
        case .simple, .space, .empty:
            return deviceLayout.regularFontSize
        case .backspace, .shift, .enter:
            return deviceLayout.specialFontSize
        case .globe:
            return deviceLayout.smallFontSize
        case .layerSwitch:
            let labelLength = self.label(shiftState: .unshifted).count
            return labelLength > 1 ? deviceLayout.smallFontSize : deviceLayout.specialFontSize
        case .layoutSwitch:
            return deviceLayout.smallFontSize
        }
    }

    func didTap(textDocumentProxy: UITextDocumentProxy, layerSwitchHandler: @escaping (Layer) -> Void, layoutSwitchHandler: @escaping (KeyboardLayout) -> Void, shiftHandler: @escaping () -> Void, autoUnshiftHandler: @escaping () -> Void, globeHandler: @escaping () -> Void) {
        // Handle the key action
        switch self {
        case .simple(let char):
            textDocumentProxy.insertText(String(char))
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
        switch self {
        case .shift:
            break
        case .simple, .backspace, .enter, .space, .layerSwitch, .layoutSwitch, .globe:
            autoUnshiftHandler()
        case .empty:
            break
        }
    }
}

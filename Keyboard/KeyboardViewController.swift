//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

enum Layer {
    case alpha
    case symbol
    case number
}

enum KeyType {
    case simple(Character)
    case backspace
    case shift
    case enter
    case space
    case layerSwitch(Layer)

    func backgroundColor() -> UIColor {
        switch self {
        case .simple, .space:
            return UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0)
        case .backspace, .shift, .enter, .layerSwitch:
            return UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1.0)
        }
    }

    func width(alphaKeyWidth: CGFloat, specialKeyWidth: CGFloat, spaceKeyWidth: CGFloat) -> CGFloat {
        switch self {
        case .space:
            return spaceKeyWidth
        case .layerSwitch, .shift, .backspace:
            return specialKeyWidth
        case .simple, .enter:
            return alphaKeyWidth
        }
    }

    func label() -> String {
        switch self {
        case .simple(let char):
            return String(char)
        case .backspace:
            return "⌫"
        case .shift:
            return "⇧"
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
        }
    }

    func fontSize() -> CGFloat {
        switch self {
        case .simple, .space, .empty:
            return 22
        case .backspace, .shift, .enter, .layerSwitch:
            return 16
        }
    }

    func didTap(textDocumentProxy: UITextDocumentProxy) {
        switch self {
        case .simple(let char):
            textDocumentProxy.insertText(String(char))
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .shift:
            // TODO: Handle shift state
            break
        case .enter:
            textDocumentProxy.insertText("\n")
        case .space:
            textDocumentProxy.insertText(" ")
        case .layerSwitch(let layer):
            // TODO: Handle layer switching
            break
        }
    }
}

struct CanaryLayout {
    static let rows: [[KeyType]] = [
        [.simple("w"), .simple("l"), .simple("y"), .simple("p"), .simple("b"), .simple("z"), .simple("f"), .simple("o"), .simple("u"), .simple("'")],
        [.simple("c"), .simple("r"), .simple("s"), .simple("t"), .simple("g"), .simple("m"), .simple("n"), .simple("e"), .simple("i"), .simple("a")],
        [.simple("q"), .simple("j"), .simple("v"), .simple("d"), .simple("k"), .simple("x"), .simple("h"), .simple("."), .simple(","), .enter],
        [.layerSwitch(.symbol), .shift, .backspace, .space, .layerSwitch(.number)],
    ]
}

class KeyboardViewController: UIInputViewController {
    private var keyTypeMap: [UIButton: KeyType] = [:]
    private let alphaKeyWidth: CGFloat = 32
    private let horizontalGap: CGFloat = 6
    private var verticalGap: CGFloat = 12
    private var specialKeyWidth: CGFloat { alphaKeyWidth * 1.5 + horizontalGap * 0.5 }
    private var spaceKeyWidth: CGFloat { alphaKeyWidth * 2 + horizontalGap }
    private let keyHeight: CGFloat = 36
    private let splitWidth: CGFloat = 10
    private let topPadding: CGFloat = 24

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboard()
    }

    private func setupKeyboard() {
        let keyboardView = createKeyboardView()
        view.addSubview(keyboardView)

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func createKeyboardView() -> UIView {
        let containerView = UIView()

        var yOffset: CGFloat = topPadding + verticalGap

        for (rowIndex, row) in CanaryLayout.rows.enumerated() {
            createRowKeys(for: row, rowIndex: rowIndex, yOffset: yOffset, in: containerView)
            yOffset += keyHeight + verticalGap
        }

        return containerView
    }

    private func createRowKeys(for row: [KeyType], rowIndex: Int, yOffset: CGFloat, in containerView: UIView) {
        let rowWidth = calculateRowWidth(for: row, rowIndex: rowIndex)
        let containerWidth = view.bounds.width

        var rowStartX: CGFloat
        if rowIndex == 3 {
            // Bottom row: align the vertical gap positions across all rows
            let referenceRowWidth = calculateRowWidth(for: CanaryLayout.rows[1], rowIndex: 1)
            let referenceRowStart = (containerWidth - referenceRowWidth) / 2
            // Position of gap in reference row (after 5 keys)
            let referenceGapPosition = referenceRowStart + (alphaKeyWidth + horizontalGap) * 5
            // Position where gap should be in bottom row (after Bksp)
            let bottomRowGapPosition = (specialKeyWidth + horizontalGap) * 2 + specialKeyWidth + horizontalGap
            rowStartX = referenceGapPosition - bottomRowGapPosition
        } else {
            rowStartX = (containerWidth - rowWidth) / 2
        }

        var xOffset: CGFloat = rowStartX

        for (keyIndex, keyType) in row.enumerated() {
            let keyButton = createKeyButton(keyType: keyType)
            let keyWidth = keyType.width(alphaKeyWidth: alphaKeyWidth, specialKeyWidth: specialKeyWidth, spaceKeyWidth: spaceKeyWidth)

            keyButton.frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: keyHeight)
            containerView.addSubview(keyButton)

            xOffset += keyWidth + horizontalGap

            // Add split gap in the middle of all rows
            let splitAfterIndex = (rowIndex == 3) ? 2 : (row.count / 2) - 1
            if keyIndex == splitAfterIndex {
                xOffset += splitWidth
            }
        }
    }

    private func calculateRowWidth(for row: [KeyType], rowIndex: Int) -> CGFloat {
        var totalWidth: CGFloat = 0

        for keyType in row {
            totalWidth += keyType.width(alphaKeyWidth: alphaKeyWidth, specialKeyWidth: specialKeyWidth, spaceKeyWidth: spaceKeyWidth)
        }

        totalWidth += CGFloat(row.count - 1) * horizontalGap

        // Add split gap for all rows
        totalWidth += splitWidth

        return totalWidth
    }



    private func createKeyButton(keyType: KeyType) -> UIButton {
        let button = UIButton(type: .system)

        let displayText = keyType.label()
        button.setTitle(displayText, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: keyType.fontSize(), weight: .regular)

        button.backgroundColor = keyType.backgroundColor()
        button.layer.cornerRadius = 5

        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        keyTypeMap[button] = keyType

        return button
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let keyType = keyTypeMap[sender] else { return }
        keyType.didTap(textDocumentProxy: textDocumentProxy)
    }
}

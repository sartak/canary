//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

struct DeviceLayout {
    let alphaKeyWidth: CGFloat
    let horizontalGap: CGFloat
    let verticalGap: CGFloat
    let keyHeight: CGFloat
    let splitWidth: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    var specialKeyWidth: CGFloat { alphaKeyWidth * 1.5 + horizontalGap * 0.5 }
    var spaceKeyWidth: CGFloat { alphaKeyWidth * 2 + horizontalGap }

    static func forCurrentDevice(containerWidth: CGFloat, containerHeight: CGFloat) -> DeviceLayout {
        // iPhone 16 Pro portrait baselines: 402pts width, 874pts height
        let referenceWidth: CGFloat = 402
        let referenceHeight: CGFloat = 874
        let widthScale = containerWidth / referenceWidth
        let heightScale = containerHeight / referenceHeight

        // Reference values from working iPhone 16 Pro layout
        let baseAlphaKeyWidth: CGFloat = 32
        let baseHorizontalGap: CGFloat = 6
        let baseVerticalGap: CGFloat = 12
        let baseKeyHeight: CGFloat = 36
        let baseSplitWidth: CGFloat = 10
        let baseTopPadding = baseVerticalGap
        let baseBottomPadding: CGFloat = 0

        let layout = DeviceLayout(
            alphaKeyWidth: baseAlphaKeyWidth * widthScale,
            horizontalGap: baseHorizontalGap * widthScale,
            verticalGap: baseVerticalGap * heightScale,
            keyHeight: baseKeyHeight * heightScale,
            splitWidth: baseSplitWidth * widthScale,
            topPadding: baseTopPadding * heightScale,
            bottomPadding: baseBottomPadding * heightScale
        )

        return layout
    }

    func totalKeyboardHeight(for layer: Layer, shifted: Bool, layout: KeyboardLayout) -> CGFloat {
        let numberOfRows = CGFloat(layout.rows(for: layer, shifted: shifted).count)
        // topPadding + rows + gaps between rows + bottomPadding
        return topPadding + (numberOfRows * keyHeight) + ((numberOfRows - 1) * verticalGap) + bottomPadding
    }
}

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
    case layoutSwitch(KeyboardLayout)
    case empty

    func backgroundColor(shifted: Bool) -> UIColor {
        switch self {
        case .simple, .space:
            return UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0)
        case .shift:
            return shifted ? UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0) : UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1.0)
        case .backspace, .enter, .layerSwitch, .layoutSwitch:
            return UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1.0)
        case .empty:
            return UIColor.clear
        }
    }

    func width(layout: DeviceLayout) -> CGFloat {
        switch self {
        case .space:
            return layout.spaceKeyWidth
        case .layerSwitch, .shift, .backspace:
            return layout.specialKeyWidth
        case .simple, .enter, .layoutSwitch, .empty:
            return layout.alphaKeyWidth
        }
    }

    func label(shifted: Bool) -> String {
        switch self {
        case .simple(let char):
            return String(char)
        case .backspace:
            return "⌫"
        case .shift:
            return shifted ? "⬆︎" : "⇧"
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
        case .empty:
            return ""
        }
    }

    func fontSize() -> CGFloat {
        switch self {
        case .simple, .space, .empty:
            return 22
        case .backspace, .shift, .enter, .layerSwitch, .layoutSwitch:
            return 16
        }
    }

    func didTap(textDocumentProxy: UITextDocumentProxy, layerSwitchHandler: @escaping (Layer) -> Void, layoutSwitchHandler: @escaping (KeyboardLayout) -> Void, shiftHandler: @escaping () -> Void, autoUnshiftHandler: @escaping () -> Void) {
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
        case .empty:
            // Do nothing for empty keys
            break
        }

        // Handle auto-unshift for all keys except shift
        switch self {
        case .shift:
            break
        case .simple, .backspace, .enter, .space, .layerSwitch, .layoutSwitch:
            autoUnshiftHandler()
        case .empty:
            break
        }
    }
}

enum KeyboardLayout {
    case canary
    case qwerty

    func rows(for layer: Layer, shifted: Bool) -> [[KeyType]] {
        switch self {
        case .canary:
            return canaryRows(for: layer, shifted: shifted)
        case .qwerty:
            return qwertyRows(for: layer, shifted: shifted)
        }
    }

    private func canaryRows(for layer: Layer, shifted: Bool) -> [[KeyType]] {
        let apostrophe: KeyType = shifted ? .simple("\"") : .simple("'")
        let period: KeyType = shifted ? .simple("!") : .simple(".")
        let comma: KeyType = shifted ? .simple("?") : .simple(",")

        switch layer {
        case .alpha:
            if shifted {
                return [
                    [.simple("W"), .simple("L"), .simple("Y"), .simple("P"), .simple("B"), .simple("Z"), .simple("F"), .simple("O"), .simple("U"), apostrophe],
                    [.simple("C"), .simple("R"), .simple("S"), .simple("T"), .simple("G"), .simple("M"), .simple("N"), .simple("E"), .simple("I"), .simple("A")],
                    [.simple("Q"), .simple("J"), .simple("V"), .simple("D"), .simple("K"), .simple("X"), .simple("H"), period, comma, .enter],
                    [.layerSwitch(.symbol), .shift, .backspace, .space, .layerSwitch(.number)],
                ]
            } else {
                return [
                    [.simple("w"), .simple("l"), .simple("y"), .simple("p"), .simple("b"), .simple("z"), .simple("f"), .simple("o"), .simple("u"), apostrophe],
                    [.simple("c"), .simple("r"), .simple("s"), .simple("t"), .simple("g"), .simple("m"), .simple("n"), .simple("e"), .simple("i"), .simple("a")],
                    [.simple("q"), .simple("j"), .simple("v"), .simple("d"), .simple("k"), .simple("x"), .simple("h"), period, comma, .enter],
                    [.layerSwitch(.symbol), .shift, .backspace, .space, .layerSwitch(.number)],
                ]
            }
        case .symbol:
            return [
                [.simple("`"), .simple("~"), .simple("\\"), .simple("{"), .simple("$"), .simple("%"), .simple("}"), .simple("/"), .simple("#"), apostrophe],
                [.simple("&"), .simple("*"), .simple("="), .simple("("), .simple("<"), .simple(">"), .simple(")"), .simple("-"), .simple("+"), .simple("|")],
                [.simple("—"), .simple("@"), .simple("_"), .simple("["), .simple("…"), .simple("^"), .simple("]"), period, comma, .enter],
                [.layerSwitch(.alpha), .shift, .backspace, .space, .layerSwitch(.number)],
            ]
        case .number:
            return [
                [.empty, .simple("6"), .simple("5"), .simple("4"), .empty, .layoutSwitch(.qwerty), .empty, .empty, .empty, apostrophe],
                [.empty, .simple("3"), .simple("2"), .simple("1"), .simple("0"), .empty, .empty, .empty, .empty, .empty],
                [.empty, .simple("9"), .simple("8"), .simple("7"), .empty, .empty, .empty, period, comma, .enter],
                [.layerSwitch(.alpha), .shift, .backspace, .space, .layerSwitch(.symbol)],
            ]
        }
    }
    
    private func qwertyRows(for layer: Layer, shifted: Bool) -> [[KeyType]] {
        let apostrophe: KeyType = shifted ? .simple("\"") : .simple("'")
        let period: KeyType = shifted ? .simple("!") : .simple(".")
        let comma: KeyType = shifted ? .simple("?") : .simple(",")

        switch layer {
        case .alpha:
            if shifted {
                return [
                    [.simple("Q"), .simple("W"), .simple("E"), .simple("R"), .simple("T"), .simple("Y"), .simple("U"), .simple("I"), .simple("O"), .simple("P")],
                    [.simple("A"), .simple("S"), .simple("D"), .simple("F"), .simple("G"), .simple("H"), .simple("J"), .simple("K"), .simple("L")],
                    [.shift, .simple("Z"), .simple("X"), .simple("C"), .simple("V"), .simple("B"), .simple("N"), .simple("M"), .backspace],
                    [.layerSwitch(.number), .layoutSwitch(.canary), .space, .enter],
                ]
            } else {
                return [
                    [.simple("q"), .simple("w"), .simple("e"), .simple("r"), .simple("t"), .simple("y"), .simple("u"), .simple("i"), .simple("o"), .simple("p")],
                    [.simple("a"), .simple("s"), .simple("d"), .simple("f"), .simple("g"), .simple("h"), .simple("j"), .simple("k"), .simple("l")],
                    [.shift, .simple("z"), .simple("x"), .simple("c"), .simple("v"), .simple("b"), .simple("n"), .simple("m"), .backspace],
                    [.layerSwitch(.number), .layoutSwitch(.canary), .space, .enter],
                ]
            }
        case .symbol:
            return [
                [.simple("["), .simple("]"), .simple("{"), .simple("}"), .simple("#"), .simple("%"), .simple("^"), .simple("*"), .simple("+"), .simple("=")],
                [.simple("_"), .simple("\\"), .simple("|"), .simple("~"), .simple("<"), .simple(">"), .simple("€"), .simple("£"), .simple("¥"), .simple("·")],
                [.layerSwitch(.number), .simple("."), .simple(","), .simple("?"), .simple("!"), .simple("'"), .backspace],
                [.layerSwitch(.alpha), .layoutSwitch(.canary), .space, .enter],
            ]
        case .number:
            return [
                [.simple("1"), .simple("2"), .simple("3"), .simple("4"), .simple("5"), .simple("6"), .simple("7"), .simple("8"), .simple("9"), .simple("0")],
                [.simple("-"), .simple("/"), .simple(":"), .simple(";"), .simple("("), .simple(")"), .simple("$"), .simple("&"), .simple("@"), .simple("\"")],
                [.layerSwitch(.symbol), .simple("."), .simple(","), .simple("?"), .simple("!"), .simple("'"), .backspace],
                [.layerSwitch(.alpha), .layoutSwitch(.canary), .space, .enter],
            ]
        }
    }
}

class KeyboardViewController: UIInputViewController {
    private var currentLayer: Layer = .alpha
    private var currentShifted: Bool = false
    private var keyTypeMap: [UIButton: KeyType] = [:]
    private var deviceLayout: DeviceLayout!
    private var heightConstraint: NSLayoutConstraint?
    private var keyboardLayout: KeyboardLayout = .canary

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboard()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.rebuildKeyboard()
        }
    }

    private func setupKeyboard() {
        let screenBounds = UIScreen.main.bounds
        let viewBounds = view.bounds
        let isLandscape = screenBounds.width > screenBounds.height

        let effectiveWidth = viewBounds.width
        let effectiveHeight = isLandscape ? screenBounds.width : screenBounds.height

        deviceLayout = DeviceLayout.forCurrentDevice(containerWidth: effectiveWidth, containerHeight: effectiveHeight)

        let keyboardView = createKeyboardView()
        view.addSubview(keyboardView)

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Set explicit height constraint for the main view
        let calculatedHeight = deviceLayout.totalKeyboardHeight(for: currentLayer, shifted: currentShifted, layout: keyboardLayout)
        heightConstraint = NSLayoutConstraint(
            item: view,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: calculatedHeight
        )
        heightConstraint?.priority = UILayoutPriority(999)
        view.addConstraint(heightConstraint!)
    }

    private func createKeyboardView() -> UIView {
        let containerView = UIView()

        var yOffset: CGFloat = deviceLayout.topPadding

        for (rowIndex, row) in keyboardLayout.rows(for: currentLayer, shifted: currentShifted).enumerated() {
            createRowKeys(for: row, rowIndex: rowIndex, yOffset: yOffset, in: containerView)
            yOffset += deviceLayout.keyHeight + deviceLayout.verticalGap
        }

        return containerView
    }

    private func createRowKeys(for row: [KeyType], rowIndex: Int, yOffset: CGFloat, in containerView: UIView) {
        let rowWidth = calculateRowWidth(for: row, rowIndex: rowIndex)
        let containerWidth = view.bounds.width

        var rowStartX: CGFloat
        if rowIndex == 3 {
            // Bottom row: align the vertical gap positions across all rows
            let referenceRowWidth = calculateRowWidth(for: keyboardLayout.rows(for: currentLayer, shifted: currentShifted)[1], rowIndex: 1)
            let referenceRowStart = (containerWidth - referenceRowWidth) / 2
            // Position of gap in reference row (after 5 keys)
            let referenceGapPosition = referenceRowStart + (deviceLayout.alphaKeyWidth + deviceLayout.horizontalGap) * 5
            // Position where gap should be in bottom row (after Bksp)
            let bottomRowGapPosition = (deviceLayout.specialKeyWidth + deviceLayout.horizontalGap) * 2 + deviceLayout.specialKeyWidth + deviceLayout.horizontalGap
            rowStartX = referenceGapPosition - bottomRowGapPosition
        } else {
            rowStartX = (containerWidth - rowWidth) / 2
        }

        var xOffset: CGFloat = rowStartX

        for (keyIndex, keyType) in row.enumerated() {
            let keyButton = createKeyButton(keyType: keyType)
            let keyWidth = keyType.width(layout: deviceLayout)

            keyButton.frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: deviceLayout.keyHeight)
            containerView.addSubview(keyButton)

            xOffset += keyWidth + deviceLayout.horizontalGap

            // Add split gap in the middle of all rows
            let splitAfterIndex = (rowIndex == 3) ? 2 : (row.count / 2) - 1
            if keyIndex == splitAfterIndex {
                xOffset += deviceLayout.splitWidth
            }
        }
    }

    private func calculateRowWidth(for row: [KeyType], rowIndex: Int) -> CGFloat {
        var totalWidth: CGFloat = 0

        for keyType in row {
            totalWidth += keyType.width(layout: deviceLayout)
        }

        totalWidth += CGFloat(row.count - 1) * deviceLayout.horizontalGap

        // Add split gap for all rows
        totalWidth += deviceLayout.splitWidth

        return totalWidth
    }



    private func createKeyButton(keyType: KeyType) -> UIButton {
        let button = UIButton(type: .system)

        let displayText = keyType.label(shifted: currentShifted)
        button.setTitle(displayText, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: keyType.fontSize(), weight: .regular)

        button.backgroundColor = keyType.backgroundColor(shifted: currentShifted)
        button.layer.cornerRadius = 5

        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        keyTypeMap[button] = keyType

        return button
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let keyType = keyTypeMap[sender] else { return }
        keyType.didTap(textDocumentProxy: textDocumentProxy,
                      layerSwitchHandler: { [weak self] newLayer in
                          self?.switchToLayer(newLayer)
                      },
                      layoutSwitchHandler: { [weak self] newLayout in
                          self?.switchToLayout(newLayout)
                      },
                      shiftHandler: { [weak self] in
                          self?.toggleShift()
                      },
                      autoUnshiftHandler: { [weak self] in
                          self?.autoUnshift()
                      })
    }

    private func toggleShift() {
        currentShifted.toggle()
        rebuildKeyboard()
    }

    private func autoUnshift() {
        if currentShifted {
            currentShifted = false
            rebuildKeyboard()
        }
    }

    private func switchToLayer(_ layer: Layer) {
        currentLayer = layer
        rebuildKeyboard()
    }
    
    private func switchToLayout(_ layout: KeyboardLayout) {
        keyboardLayout = layout
        currentLayer = .alpha
        rebuildKeyboard()
    }

    private func rebuildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }
        keyTypeMap.removeAll()
        setupKeyboard()
    }
}

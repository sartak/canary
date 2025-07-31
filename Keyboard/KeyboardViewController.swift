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
        let baseSplitWidth: CGFloat = 16
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

    func totalKeyboardHeight(for layer: Layer, shifted: Bool, layout: KeyboardLayout, needsGlobe: Bool) -> CGFloat {
        let numberOfRows = CGFloat(layout.rows(for: layer, shifted: shifted, needsGlobe: needsGlobe).count)
        // topPadding + rows + gaps between rows + bottomPadding
        return topPadding + (numberOfRows * keyHeight) + ((numberOfRows - 1) * verticalGap) + bottomPadding
    }
}

enum Layer {
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

enum KeyType {
    case simple(Character)
    case backspace
    case shift
    case enter
    case space
    case layerSwitch(Layer)
    case layoutSwitch(KeyboardLayout)
    case globe
    case empty

    func backgroundColor(shifted: Bool) -> UIColor {
        switch self {
        case .simple, .space:
            return UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0)
        case .shift:
            return shifted ? UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0) : UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1.0)
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1.0)
        case .empty:
            return UIColor.clear
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
        case .globe:
            return "◉"
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
            let labelLength = self.label(shifted: false).count
            return labelLength > 1 ? 12 : 16
        case .layoutSwitch:
            return 12
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

enum KeyboardLayout {
    case canary
    case qwerty

    func rows(for layer: Layer, shifted: Bool, needsGlobe: Bool) -> [[KeyType]] {
        switch self {
        case .canary:
            let baseRows = canaryRows(for: layer, shifted: shifted)
            if needsGlobe {
                return baseRows
            } else {
                // Filter out globe key from all rows
                return baseRows.map { row in
                    row.filter { key in
                        if case .globe = key {
                            return false
                        }
                        return true
                    }
                }
            }
        case .qwerty:
            let baseRows = qwertyRows(for: layer, shifted: shifted)
            if needsGlobe {
                return baseRows
            } else {
                // Filter out globe key from all rows
                return baseRows.map { row in
                    row.filter { key in
                        if case .globe = key {
                            return false
                        }
                        return true
                    }
                }
            }
        }
    }

    func nodeRows(for layer: Layer, shifted: Bool, layout: DeviceLayout, needsGlobe: Bool) -> [[Node]] {
        switch self {
        case .canary:
            return canaryNodeRows(for: layer, shifted: shifted, layout: layout, needsGlobe: needsGlobe)
        case .qwerty:
            return qwertyNodeRows(for: layer, shifted: shifted, layout: layout, needsGlobe: needsGlobe)
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
                    [.globe, .layerSwitch(.symbol), .shift, .backspace, .space, .layerSwitch(.number)],
                ]
            } else {
                return [
                    [.simple("w"), .simple("l"), .simple("y"), .simple("p"), .simple("b"), .simple("z"), .simple("f"), .simple("o"), .simple("u"), apostrophe],
                    [.simple("c"), .simple("r"), .simple("s"), .simple("t"), .simple("g"), .simple("m"), .simple("n"), .simple("e"), .simple("i"), .simple("a")],
                    [.simple("q"), .simple("j"), .simple("v"), .simple("d"), .simple("k"), .simple("x"), .simple("h"), period, comma, .enter],
                    [.globe, .layerSwitch(.symbol), .shift, .backspace, .space, .layerSwitch(.number)],
                ]
            }
        case .symbol:
            return [
                [.simple("`"), .simple("~"), .simple("\\"), .simple("{"), .simple("$"), .simple("%"), .simple("}"), .simple("/"), .simple("#"), apostrophe],
                [.simple("&"), .simple("*"), .simple("="), .simple("("), .simple("<"), .simple(">"), .simple(")"), .simple("-"), .simple("+"), .simple("|")],
                [.simple("—"), .simple("@"), .simple("_"), .simple("["), .simple("…"), .simple("^"), .simple("]"), period, comma, .enter],
                [.globe, .layerSwitch(.alpha), .shift, .backspace, .space, .layerSwitch(.number)],
            ]
        case .number:
            return [
                [.empty, .simple("6"), .simple("5"), .simple("4"), .empty, .layoutSwitch(.qwerty), .empty, .empty, .empty, apostrophe],
                [.empty, .simple("3"), .simple("2"), .simple("1"), .simple("0"), .empty, .empty, .empty, .empty, .empty],
                [.empty, .simple("9"), .simple("8"), .simple("7"), .empty, .empty, .empty, period, comma, .enter],
                [.globe, .layerSwitch(.alpha), .shift, .backspace, .space, .layerSwitch(.symbol)],
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
                    [.layerSwitch(.number), .layoutSwitch(.canary), .globe, .space, .enter],
                ]
            } else {
                return [
                    [.simple("q"), .simple("w"), .simple("e"), .simple("r"), .simple("t"), .simple("y"), .simple("u"), .simple("i"), .simple("o"), .simple("p")],
                    [.simple("a"), .simple("s"), .simple("d"), .simple("f"), .simple("g"), .simple("h"), .simple("j"), .simple("k"), .simple("l")],
                    [.shift, .simple("z"), .simple("x"), .simple("c"), .simple("v"), .simple("b"), .simple("n"), .simple("m"), .backspace],
                    [.layerSwitch(.number), .layoutSwitch(.canary), .globe, .space, .enter],
                ]
            }
        case .symbol:
            return [
                [.simple("["), .simple("]"), .simple("{"), .simple("}"), .simple("#"), .simple("%"), .simple("^"), .simple("*"), .simple("+"), .simple("=")],
                [.simple("_"), .simple("\\"), .simple("|"), .simple("~"), .simple("<"), .simple(">"), .simple("€"), .simple("£"), .simple("¥"), .simple("·")],
                [.layerSwitch(.number), .simple("."), .simple(","), .simple("?"), .simple("!"), .simple("'"), .backspace],
                [.layerSwitch(.alpha), .layoutSwitch(.canary), .globe, .space, .enter],
            ]
        case .number:
            return [
                [.simple("1"), .simple("2"), .simple("3"), .simple("4"), .simple("5"), .simple("6"), .simple("7"), .simple("8"), .simple("9"), .simple("0")],
                [.simple("-"), .simple("/"), .simple(":"), .simple(";"), .simple("("), .simple(")"), .simple("$"), .simple("&"), .simple("@"), .simple("\"")],
                [.layerSwitch(.symbol), .simple("."), .simple(","), .simple("?"), .simple("!"), .simple("'"), .backspace],
                [.layerSwitch(.alpha), .layoutSwitch(.canary), .globe, .space, .enter],
            ]
        }
    }

    private func canaryNodeRows(for layer: Layer, shifted: Bool, layout: DeviceLayout, needsGlobe: Bool) -> [[Node]] {
        let keyRows = self.rows(for: layer, shifted: shifted, needsGlobe: needsGlobe)
        let allNodeRows = keyRows.enumerated().map { rowIndex, row in
            var nodeRow: [Node] = []

            for (keyIndex, keyType) in row.enumerated() {
                // Add the key with Canary-specific sizing
                let keyWidth: CGFloat
                switch keyType {
                case .space:
                    keyWidth = layout.alphaKeyWidth * 2 + layout.horizontalGap
                case .layerSwitch, .shift, .backspace:
                    // Make special keys narrower when globe key is present
                    keyWidth = needsGlobe ? layout.alphaKeyWidth * 1.3 : (layout.alphaKeyWidth * 1.5 + layout.horizontalGap * 0.5)
                case .simple, .enter, .layoutSwitch, .globe, .empty:
                    keyWidth = layout.alphaKeyWidth
                }
                nodeRow.append(.key(keyType, keyWidth))

                // Add split gap in middle
                let splitAfterIndex: Int
                if rowIndex == 3 {
                    // Bottom row: split after backspace (index 3 with globe, index 2 without globe)
                    splitAfterIndex = needsGlobe ? 3 : 2
                } else {
                    splitAfterIndex = (row.count / 2) - 1
                }

                if keyIndex == splitAfterIndex {
                    nodeRow.append(.split(layout.splitWidth))
                } else if keyIndex < row.count - 1 {
                    // Add gap after key (except last key and before split)
                    nodeRow.append(.gap(layout.horizontalGap))
                }
            }

            return nodeRow
        }

        // Align bottom row split with first row
        return allNodeRows.enumerated().map { rowIndex, nodeRow in
            if rowIndex == 3 {
                // Find split positions in both rows
                let firstRowSplitIndex = allNodeRows[0].firstIndex { if case .split = $0 { return true } else { return false } }!
                let bottomRowSplitIndex = nodeRow.firstIndex { if case .split = $0 { return true } else { return false } }!

                // Calculate left and right side widths using split as delimiter
                let firstRowLeftWidth = Node.calculateRowWidth(for: Array(allNodeRows[0].prefix(firstRowSplitIndex)))
                let firstRowRightWidth = Node.calculateRowWidth(for: Array(allNodeRows[0].suffix(from: firstRowSplitIndex + 1)))

                let bottomRowLeftWidth = Node.calculateRowWidth(for: Array(nodeRow.prefix(bottomRowSplitIndex)))
                let bottomRowRightWidth = Node.calculateRowWidth(for: Array(nodeRow.suffix(from: bottomRowSplitIndex + 1)))

                let leftGap = firstRowLeftWidth - bottomRowLeftWidth
                let rightGap = firstRowRightWidth - bottomRowRightWidth


                return [.gap(max(0, leftGap))] + nodeRow + [.gap(max(0, rightGap))]
            }
            return nodeRow
        }
    }

    private func qwertySpecialKeyWidth(_ layout: DeviceLayout) -> CGFloat {
        return round(layout.alphaKeyWidth * 1.2)
    }

    private func qwertyThirdRowSimpleKeyWidth(_ layout: DeviceLayout) -> CGFloat {
        return round(layout.alphaKeyWidth * 1.4)
    }

    private func qwertyStandardRowWidth(_ layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        let firstRow = KeyboardLayout.qwerty.rows(for: .alpha, shifted: false, needsGlobe: needsGlobe)[0]
        return layout.alphaKeyWidth * CGFloat(firstRow.count) + layout.horizontalGap * CGFloat(firstRow.count - 1)
    }

    private func qwertyThirdRowSpecialGap(layer: Layer, _ layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        let thirdRow = KeyboardLayout.qwerty.rows(for: layer, shifted: false, needsGlobe: needsGlobe)[2]
        let specialKeyWidth = qwertySpecialKeyWidth(layout)
        let simpleKeyWidth = (layer == .number || layer == .symbol) ? qwertyThirdRowSimpleKeyWidth(layout) : layout.alphaKeyWidth
        let middleKeysWidth = CGFloat(thirdRow.count - 2) * simpleKeyWidth + CGFloat(thirdRow.count - 3) * layout.horizontalGap
        let availableWidth = qwertyStandardRowWidth(layout, needsGlobe: needsGlobe)
        let totalSpecialWidth = specialKeyWidth * 2
        let totalGapWidth = availableWidth - totalSpecialWidth - middleKeysWidth
        return totalGapWidth / 2
    }

    private func qwertyEnterKeyWidth(_ layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        let specialKeyWidth = qwertySpecialKeyWidth(layout)
        let specialGap = qwertyThirdRowSpecialGap(layer: .alpha, layout, needsGlobe: needsGlobe)
        return layout.alphaKeyWidth + specialKeyWidth + specialGap
    }

    private func qwertySpaceKeyWidth(_ layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        let bottomRow = KeyboardLayout.qwerty.rows(for: .alpha, shifted: false, needsGlobe: needsGlobe)[3]
        let availableWidth = qwertyStandardRowWidth(layout, needsGlobe: needsGlobe)

        let otherKeysWidth: CGFloat = bottomRow.compactMap { keyType -> CGFloat? in
            if case .space = keyType {
                return nil
            }
            return qwertyKeyWidth(for: keyType, rowIndex: 3, layer: .alpha, layout: layout, needsGlobe: needsGlobe)
        }.reduce(0.0, +)

        let gapsWidth = layout.horizontalGap * CGFloat(bottomRow.count - 1)
        let spaceWidth = availableWidth - otherKeysWidth - gapsWidth

        return spaceWidth
    }

    private func qwertyKeyWidth(for keyType: KeyType, rowIndex: Int, layer: Layer, layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        switch keyType {
        case .space:
            return qwertySpaceKeyWidth(layout, needsGlobe: needsGlobe)
        case .enter:
            return qwertyEnterKeyWidth(layout, needsGlobe: needsGlobe)
        case .layerSwitch, .shift, .backspace, .layoutSwitch:
            return qwertySpecialKeyWidth(layout)
        case .simple, .globe, .empty:
            // Third row simple keys are 40% larger on number/symbol layers
            if rowIndex == 2 && (layer == .number || layer == .symbol) {
                return qwertyThirdRowSimpleKeyWidth(layout)
            } else {
                return layout.alphaKeyWidth
            }
        }
    }

    private func qwertyNodeRows(for layer: Layer, shifted: Bool, layout: DeviceLayout, needsGlobe: Bool) -> [[Node]] {
        let keyRows = self.rows(for: layer, shifted: shifted, needsGlobe: needsGlobe)
        return keyRows.enumerated().map { rowIndex, row in
            var nodeRow: [Node] = []

            for (keyIndex, keyType) in row.enumerated() {
                // Add the key with QWERTY-specific sizing
                let keyWidth = qwertyKeyWidth(for: keyType, rowIndex: rowIndex, layer: layer, layout: layout, needsGlobe: needsGlobe)
                nodeRow.append(.key(keyType, keyWidth))

                // Add gap after key (except last key)
                if keyIndex < row.count - 1 {
                    let gapWidth = if rowIndex == 2 && (keyIndex == 0 || keyIndex == row.count - 2) {
                        qwertyThirdRowSpecialGap(layer: layer, layout, needsGlobe: false)
                    } else {
                        layout.horizontalGap
                    }
                    nodeRow.append(.gap(gapWidth))
                }
            }

            return nodeRow
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
    private var needsGlobe: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        needsGlobe = needsInputModeSwitchKey
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
        let calculatedHeight = deviceLayout.totalKeyboardHeight(for: currentLayer, shifted: currentShifted, layout: keyboardLayout, needsGlobe: needsGlobe)
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

        for (rowIndex, row) in keyboardLayout.nodeRows(for: currentLayer, shifted: currentShifted, layout: deviceLayout, needsGlobe: needsGlobe).enumerated() {
            createRowKeys(for: row, rowIndex: rowIndex, yOffset: yOffset, in: containerView)
            yOffset += deviceLayout.keyHeight + deviceLayout.verticalGap
        }

        return containerView
    }

    private func createRowKeys(for row: [Node], rowIndex: Int, yOffset: CGFloat, in containerView: UIView) {
        let containerWidth = view.bounds.width
        let rowWidth = Node.calculateRowWidth(for: row)
        let rowStartX = (containerWidth - rowWidth) / 2
        var xOffset: CGFloat = rowStartX

        for node in row {
            switch node {
            case .key(let keyType, let keyWidth):
                let keyButton = createKeyButton(keyType: keyType)
                keyButton.frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: deviceLayout.keyHeight)
                containerView.addSubview(keyButton)
                xOffset += keyWidth
            case .gap(let gapWidth):
                xOffset += gapWidth
            case .split(let splitWidth):
                xOffset += splitWidth
            }
        }
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
                      },
                      globeHandler: { [weak self] in
                          self?.advanceToNextInputMode()
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

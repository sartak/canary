//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let primaryKeyColor = UIColor(white: 115/255.0, alpha: 1.0)
private let secondaryKeyColor = UIColor(white: 63/255.0, alpha: 1.0)
private let popoutFontSize: CGFloat = 44
private let largeScreenWidth: CGFloat = 600

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
        let baseTopPadding: CGFloat = 48
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

struct KeyData {
    let index: Int
    let keyType: KeyType
    let frame: CGRect
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
            return primaryKeyColor
        case .shift:
            return shifted ? primaryKeyColor : secondaryKeyColor
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return secondaryKeyColor
        case .empty:
            return UIColor.clear
        }
    }

    func tappedBackgroundColor(shifted: Bool, isLargeScreen: Bool) -> UIColor {
        switch self {
        case .simple:
            return isLargeScreen ? secondaryKeyColor : primaryKeyColor
        case .space:
            return secondaryKeyColor
        case .shift:
            return shifted ? secondaryKeyColor : primaryKeyColor
        case .backspace, .enter, .layerSwitch, .layoutSwitch, .globe:
            return primaryKeyColor
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

class KeyboardTouchView: UIView {
    var keyData: [KeyData] = []
    var currentShifted: Bool = false
    var keysWithPopouts: Set<Int> = []
    var onKeyTouchDown: ((KeyData) -> Void)?
    var onKeyTouchUp: ((KeyData) -> Void)?

    // Multi-touch support
    private var activeTouches: [UITouch: KeyData] = [:]
    private var touchQueue: [UITouch] = []
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
                activeTouches[touch] = key
                touchQueue.append(touch)
                pressedKeys.insert(key.index)
                onKeyTouchDown?(key)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if activeTouches[touch] != nil {
                processQueueUpToTouch(touch)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if activeTouches[touch] != nil {
                processQueueUpToTouch(touch)
            }
        }
    }

    private func processQueueUpToTouch(_ endingTouch: UITouch) {
        guard let endingTouchIndex = touchQueue.firstIndex(of: endingTouch) else { return }

        // Process all touches up to and including the ending touch, in order
        let touchesToProcess = Array(touchQueue[0...endingTouchIndex])

        for touch in touchesToProcess {
            if let key = activeTouches[touch] {
                onKeyTouchUp?(key)
                activeTouches.removeValue(forKey: touch)
                pressedKeys.remove(key.index)
            }
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

class KeyboardViewController: UIInputViewController {
    private var currentLayer: Layer = .alpha
    private var currentShifted: Bool = false
    private var keyboardTouchView: KeyboardTouchView!
    private var deviceLayout: DeviceLayout!
    private var heightConstraint: NSLayoutConstraint?
    private var keyboardLayout: KeyboardLayout = .canary
    private var needsGlobe: Bool = false
    private var keyPopouts: [Int: UIView] = [:]

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

        keyboardTouchView = KeyboardTouchView()
        keyboardTouchView.backgroundColor = UIColor.clear
        keyboardTouchView.currentShifted = currentShifted
        keyboardTouchView.keyData = createKeyData()
        keyboardTouchView.setNeedsDisplay()

        keyboardTouchView.onKeyTouchDown = { [weak self] keyData in
            self?.handleKeyTouchDown(keyData)
        }

        keyboardTouchView.onKeyTouchUp = { [weak self] keyData in
            self?.handleKeyTouchUp(keyData)
        }

        // Calculate keyboard height first
        let calculatedHeight = deviceLayout.totalKeyboardHeight(for: currentLayer, shifted: currentShifted, layout: keyboardLayout, needsGlobe: needsGlobe)

        view.addSubview(keyboardTouchView)

        keyboardTouchView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardTouchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardTouchView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardTouchView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardTouchView.heightAnchor.constraint(equalToConstant: calculatedHeight)
        ])

        // Set explicit height constraint for the main view
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

    private func createKeyData() -> [KeyData] {
        var keys: [KeyData] = []
        var yOffset: CGFloat = deviceLayout.topPadding

        for (rowIndex, row) in keyboardLayout.nodeRows(for: currentLayer, shifted: currentShifted, layout: deviceLayout, needsGlobe: needsGlobe).enumerated() {
            let rowKeys = createRowKeyData(for: row, rowIndex: rowIndex, yOffset: yOffset, startingIndex: keys.count)
            keys.append(contentsOf: rowKeys)
            yOffset += deviceLayout.keyHeight + deviceLayout.verticalGap
        }

        return keys
    }

    private func createRowKeyData(for row: [Node], rowIndex: Int, yOffset: CGFloat, startingIndex: Int) -> [KeyData] {
        let containerWidth = view.bounds.width
        let rowWidth = Node.calculateRowWidth(for: row)
        let rowStartX = (containerWidth - rowWidth) / 2
        var xOffset: CGFloat = rowStartX
        var keys: [KeyData] = []

        for node in row {
            switch node {
            case .key(let keyType, let keyWidth):
                let frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: deviceLayout.keyHeight)
                let isLargeScreen = view.bounds.width > largeScreenWidth
                let keyData = KeyData(
                    index: startingIndex + keys.count,
                    keyType: keyType,
                    frame: frame
                )
                keys.append(keyData)
                xOffset += keyWidth
            case .gap(let gapWidth):
                xOffset += gapWidth
            case .split(let splitWidth):
                xOffset += splitWidth
            }
        }

        return keys
    }





    private func handleKeyTouchDown(_ keyData: KeyData) {
        keyboardTouchView.setNeedsDisplay()

        let isLargeScreen = view.bounds.width > largeScreenWidth
        if case .simple = keyData.keyType, !isLargeScreen {
            keyboardTouchView.keysWithPopouts.insert(keyData.index)
            showKeyPopout(for: keyData)
        }
    }

    private func handleKeyTouchUp(_ keyData: KeyData) {
        keyboardTouchView.setNeedsDisplay()

        keyboardTouchView.keysWithPopouts.remove(keyData.index)
        hideKeyPopout(for: keyData)

        // Handle the key tap
        keyData.keyType.didTap(textDocumentProxy: textDocumentProxy,
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
        keyPopouts.removeAll()
        setupKeyboard()
    }

    private func showKeyPopout(for keyData: KeyData) {
        // Scale popout size based on device layout like keys
        let basePopoutTopWidth: CGFloat = 45
        let basePopoutHeight: CGFloat = 55
        let screenBounds = UIScreen.main.bounds
        let isLandscape = screenBounds.width > screenBounds.height
        let effectiveWidth = view.bounds.width
        let effectiveHeight = isLandscape ? screenBounds.width : screenBounds.height
        let referenceWidth: CGFloat = 402
        let referenceHeight: CGFloat = 874
        let widthScale = effectiveWidth / referenceWidth
        let heightScale = effectiveHeight / referenceHeight

        let popoutTopWidth = basePopoutTopWidth * widthScale
        let popoutHeight = basePopoutHeight * heightScale
        let keyWidth = keyData.frame.width

        let popout = UIView()
        popout.backgroundColor = .clear
        popout.isUserInteractionEnabled = false

        // Create funnel shape using CAShapeLayer
        let shapeLayer = CAShapeLayer()
        let path = UIBezierPath()

        // Start from top-left of rounded rectangle
        path.move(to: CGPoint(x: 5, y: 0))
        path.addLine(to: CGPoint(x: popoutTopWidth - 5, y: 0))
        path.addQuadCurve(to: CGPoint(x: popoutTopWidth, y: 5), controlPoint: CGPoint(x: popoutTopWidth, y: 0))
        path.addLine(to: CGPoint(x: popoutTopWidth, y: popoutHeight - 15))

        // Funnel down to key width with curves
        let funnelStartX = max(0, (popoutTopWidth - keyWidth) / 2)
        let funnelEndX = popoutTopWidth - funnelStartX
        let controlY = popoutHeight - 5
        let controlInset: CGFloat = 8

        path.addQuadCurve(to: CGPoint(x: funnelEndX, y: popoutHeight),
                         controlPoint: CGPoint(x: popoutTopWidth - controlInset, y: controlY))
        path.addLine(to: CGPoint(x: funnelStartX, y: popoutHeight))
        path.addQuadCurve(to: CGPoint(x: 0, y: popoutHeight - 15),
                         controlPoint: CGPoint(x: controlInset, y: controlY))

        // Left side of rounded rectangle
        path.addLine(to: CGPoint(x: 0, y: 5))
        path.addQuadCurve(to: CGPoint(x: 5, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        path.close()

        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = primaryKeyColor.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 3

        // Create shadow path for top three edges only
        let shadowPath = UIBezierPath()
        shadowPath.move(to: CGPoint(x: 5, y: 0))
        shadowPath.addLine(to: CGPoint(x: popoutTopWidth - 5, y: 0))
        shadowPath.addQuadCurve(to: CGPoint(x: popoutTopWidth, y: 5), controlPoint: CGPoint(x: popoutTopWidth, y: 0))
        shadowPath.addLine(to: CGPoint(x: popoutTopWidth, y: popoutHeight - 15))
        shadowPath.addQuadCurve(to: CGPoint(x: 0, y: popoutHeight - 15),
                               controlPoint: CGPoint(x: popoutTopWidth / 2, y: controlY))
        shadowPath.addLine(to: CGPoint(x: 0, y: 5))
        shadowPath.addQuadCurve(to: CGPoint(x: 5, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        shadowPath.close()

        shapeLayer.shadowPath = shadowPath.cgPath
        popout.layer.addSublayer(shapeLayer)

        let label = UILabel()
        label.text = keyData.keyType.label(shifted: currentShifted)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)
        label.textAlignment = .center

        popout.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * 0.35)
        ])

        view.addSubview(popout)
        keyPopouts[keyData.index] = popout

        // Position popout above the key (always centered)
        let keyCenter = CGPoint(x: keyData.frame.midX, y: keyData.frame.midY)
        let popoutX = keyCenter.x - popoutTopWidth / 2

        popout.frame = CGRect(
            x: popoutX,
            y: keyCenter.y - popoutHeight - 10,
            width: popoutTopWidth,
            height: popoutHeight
        )
    }

    private func hideKeyPopout(for keyData: KeyData) {
        guard let popout = keyPopouts[keyData.index] else { return }
        popout.removeFromSuperview()
        keyPopouts.removeValue(forKey: keyData.index)
    }
}

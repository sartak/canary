//
//  KeyboardLayout.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

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
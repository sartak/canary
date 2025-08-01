//
//  KeyboardLayout.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

enum Layer: Equatable {
    case alpha
    case symbol
    case number
}

enum Node {
    case key(Key, CGFloat)
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
    let key: Key
    let frame: CGRect
}

enum KeyboardLayout: Equatable {
    case canary
    case qwerty

    func rows(for layer: Layer, shifted: Bool, needsGlobe: Bool) -> [[Key]] {
        switch self {
        case .canary:
            let baseRows = canaryRows(for: layer, shifted: shifted)
            if needsGlobe {
                return baseRows
            } else {
                // Filter out globe key from all rows
                return baseRows.map { row in
                    row.filter { key in
                        if case .globe = key.keyType {
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
                        if case .globe = key.keyType {
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

    private func canaryRows(for layer: Layer, shifted: Bool) -> [[Key]] {
        let apostrophe = Key(shifted ? .simple("\"") : .simple("'"))
        let period = Key(shifted ? .simple("!") : .simple("."))
        let comma = Key(shifted ? .simple("?") : .simple(","))

        switch layer {
        case .alpha:
            if shifted {
                return [
                    [Key(.simple("W")), Key(.simple("L")), Key(.simple("Y")), Key(.simple("P")), Key(.simple("B")), Key(.simple("Z")), Key(.simple("F")), Key(.simple("O")), Key(.simple("U")), apostrophe],
                    [Key(.simple("C")), Key(.simple("R")), Key(.simple("S")), Key(.simple("T")), Key(.simple("G")), Key(.simple("M")), Key(.simple("N")), Key(.simple("E")), Key(.simple("I")), Key(.simple("A"))],
                    [Key(.simple("Q")), Key(.simple("J")), Key(.simple("V")), Key(.simple("D")), Key(.simple("K")), Key(.simple("X")), Key(.simple("H")), period, comma, Key(.enter)],
                    [Key(.globe), Key(.layerSwitch(.symbol)), Key(.shift, doubleTapBehavior: .capsLock), Key(.backspace, longPressBehavior: .repeating), Key(.space), Key(.layerSwitch(.number))],
                ]
            } else {
                return [
                    [Key(.simple("w")), Key(.simple("l")), Key(.simple("y")), Key(.simple("p")), Key(.simple("b")), Key(.simple("z")), Key(.simple("f")), Key(.simple("o")), Key(.simple("u")), apostrophe],
                    [Key(.simple("c")), Key(.simple("r")), Key(.simple("s")), Key(.simple("t")), Key(.simple("g")), Key(.simple("m")), Key(.simple("n")), Key(.simple("e")), Key(.simple("i")), Key(.simple("a"))],
                    [Key(.simple("q")), Key(.simple("j")), Key(.simple("v")), Key(.simple("d")), Key(.simple("k")), Key(.simple("x")), Key(.simple("h")), period, comma, Key(.enter)],
                    [Key(.globe), Key(.layerSwitch(.symbol)), Key(.shift, doubleTapBehavior: .capsLock), Key(.backspace, longPressBehavior: .repeating), Key(.space), Key(.layerSwitch(.number))],
                ]
            }
        case .symbol:
            return [
                [Key(.simple("`")), Key(.simple("~")), Key(.simple("\\")), Key(.simple("{")), Key(.simple("$")), Key(.simple("%")), Key(.simple("}")), Key(.simple("/")), Key(.simple("#")), apostrophe],
                [Key(.simple("&")), Key(.simple("*")), Key(.simple("=")), Key(.simple("(")), Key(.simple("<")), Key(.simple(">")), Key(.simple(")")), Key(.simple("-")), Key(.simple("+")), Key(.simple("|"))],
                [Key(.simple("—")), Key(.simple("@")), Key(.simple("_")), Key(.simple("[")), Key(.simple("…")), Key(.simple("^")), Key(.simple("]")), period, comma, Key(.enter)],
                [Key(.globe), Key(.layerSwitch(.alpha)), Key(.shift, doubleTapBehavior: .capsLock), Key(.backspace, longPressBehavior: .repeating), Key(.space), Key(.layerSwitch(.number))],
            ]
        case .number:
            return [
                [Key(.empty), Key(.simple("6")), Key(.simple("5")), Key(.simple("4")), Key(.empty), Key(.layoutSwitch(.qwerty)), Key(.empty), Key(.empty), Key(.empty), apostrophe],
                [Key(.empty), Key(.simple("3")), Key(.simple("2")), Key(.simple("1")), Key(.simple("0")), Key(.empty), Key(.empty), Key(.empty), Key(.empty), Key(.empty)],
                [Key(.empty), Key(.simple("9")), Key(.simple("8")), Key(.simple("7")), Key(.empty), Key(.empty), Key(.empty), period, comma, Key(.enter)],
                [Key(.globe), Key(.layerSwitch(.alpha)), Key(.shift, doubleTapBehavior: .capsLock), Key(.backspace, longPressBehavior: .repeating), Key(.space), Key(.layerSwitch(.symbol))],
            ]
        }
    }

    private func qwertyRows(for layer: Layer, shifted: Bool) -> [[Key]] {
        switch layer {
        case .alpha:
            if shifted {
                return [
                    [Key(.simple("Q")), Key(.simple("W")), Key(.simple("E")), Key(.simple("R")), Key(.simple("T")), Key(.simple("Y")), Key(.simple("U")), Key(.simple("I")), Key(.simple("O")), Key(.simple("P"))],
                    [Key(.simple("A")), Key(.simple("S")), Key(.simple("D")), Key(.simple("F")), Key(.simple("G")), Key(.simple("H")), Key(.simple("J")), Key(.simple("K")), Key(.simple("L"))],
                    [Key(.shift, doubleTapBehavior: .capsLock), Key(.simple("Z")), Key(.simple("X")), Key(.simple("C")), Key(.simple("V")), Key(.simple("B")), Key(.simple("N")), Key(.simple("M")), Key(.backspace, longPressBehavior: .repeating)],
                    [Key(.layerSwitch(.number)), Key(.layoutSwitch(.canary)), Key(.globe), Key(.space), Key(.enter)],
                ]
            } else {
                return [
                    [Key(.simple("q")), Key(.simple("w")), Key(.simple("e")), Key(.simple("r")), Key(.simple("t")), Key(.simple("y")), Key(.simple("u")), Key(.simple("i")), Key(.simple("o")), Key(.simple("p"))],
                    [Key(.simple("a")), Key(.simple("s")), Key(.simple("d")), Key(.simple("f")), Key(.simple("g")), Key(.simple("h")), Key(.simple("j")), Key(.simple("k")), Key(.simple("l"))],
                    [Key(.shift, doubleTapBehavior: .capsLock), Key(.simple("z")), Key(.simple("x")), Key(.simple("c")), Key(.simple("v")), Key(.simple("b")), Key(.simple("n")), Key(.simple("m")), Key(.backspace, longPressBehavior: .repeating)],
                    [Key(.layerSwitch(.number)), Key(.layoutSwitch(.canary)), Key(.globe), Key(.space), Key(.enter)],
                ]
            }
        case .symbol:
            return [
                [Key(.simple("[")), Key(.simple("]")), Key(.simple("{")), Key(.simple("}")), Key(.simple("#")), Key(.simple("%")), Key(.simple("^")), Key(.simple("*")), Key(.simple("+")), Key(.simple("="))],
                [Key(.simple("_")), Key(.simple("\\")), Key(.simple("|")), Key(.simple("~")), Key(.simple("<")), Key(.simple(">")), Key(.simple("€")), Key(.simple("£")), Key(.simple("¥")), Key(.simple("·"))],
                [Key(.layerSwitch(.number)), Key(.simple(".")), Key(.simple(",")), Key(.simple("?")), Key(.simple("!")), Key(.simple("'")), Key(.backspace, longPressBehavior: .repeating)],
                [Key(.layerSwitch(.alpha)), Key(.layoutSwitch(.canary)), Key(.globe), Key(.space), Key(.enter)],
            ]
        case .number:
            return [
                [Key(.simple("1")), Key(.simple("2")), Key(.simple("3")), Key(.simple("4")), Key(.simple("5")), Key(.simple("6")), Key(.simple("7")), Key(.simple("8")), Key(.simple("9")), Key(.simple("0"))],
                [Key(.simple("-")), Key(.simple("/")), Key(.simple(":")), Key(.simple(";")), Key(.simple("(")), Key(.simple(")")), Key(.simple("$")), Key(.simple("&")), Key(.simple("@")), Key(.simple("\""))],
                [Key(.layerSwitch(.symbol)), Key(.simple(".")), Key(.simple(",")), Key(.simple("?")), Key(.simple("!")), Key(.simple("'")), Key(.backspace, longPressBehavior: .repeating)],
                [Key(.layerSwitch(.alpha)), Key(.layoutSwitch(.canary)), Key(.globe), Key(.space), Key(.enter)],
            ]
        }
    }

    private func canaryNodeRows(for layer: Layer, shifted: Bool, layout: DeviceLayout, needsGlobe: Bool) -> [[Node]] {
        let keyRows = self.rows(for: layer, shifted: shifted, needsGlobe: needsGlobe)
        let allNodeRows = keyRows.enumerated().map { rowIndex, row in
            var nodeRow: [Node] = []

            for (keyIndex, key) in row.enumerated() {
                // Add the key with Canary-specific sizing
                let keyWidth: CGFloat
                switch key.keyType {
                case .space:
                    keyWidth = layout.alphaKeyWidth * 2 + layout.horizontalGap
                case .layerSwitch, .shift, .backspace:
                    // Make special keys narrower when globe key is present
                    keyWidth = needsGlobe ? layout.alphaKeyWidth * 1.3 : (layout.alphaKeyWidth * 1.5 + layout.horizontalGap * 0.5)
                case .simple, .enter, .layoutSwitch, .globe, .empty:
                    keyWidth = layout.alphaKeyWidth
                }
                nodeRow.append(.key(key, keyWidth))

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

        let otherKeysWidth: CGFloat = bottomRow.compactMap { key -> CGFloat? in
            if case .space = key.keyType {
                return nil
            }
            return qwertyKeyWidth(for: key, rowIndex: 3, layer: .alpha, layout: layout, needsGlobe: needsGlobe)
        }.reduce(0.0, +)

        let gapsWidth = layout.horizontalGap * CGFloat(bottomRow.count - 1)
        let spaceWidth = availableWidth - otherKeysWidth - gapsWidth

        return spaceWidth
    }

    private func qwertyKeyWidth(for key: Key, rowIndex: Int, layer: Layer, layout: DeviceLayout, needsGlobe: Bool) -> CGFloat {
        switch key.keyType {
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

            for (keyIndex, key) in row.enumerated() {
                // Add the key with QWERTY-specific sizing
                let keyWidth = qwertyKeyWidth(for: key, rowIndex: rowIndex, layer: layer, layout: layout, needsGlobe: needsGlobe)
                nodeRow.append(.key(key, keyWidth))

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

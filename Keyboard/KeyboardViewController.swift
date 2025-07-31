//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let largeScreenWidth: CGFloat = 600

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
        let popout = KeyPopoutView.createPopout(for: keyData, shifted: currentShifted, containerView: view)
        view.addSubview(popout)
        keyPopouts[keyData.index] = popout
    }

    private func hideKeyPopout(for keyData: KeyData) {
        guard let popout = keyPopouts[keyData.index] else { return }
        popout.removeFromSuperview()
        keyPopouts.removeValue(forKey: keyData.index)
    }
}

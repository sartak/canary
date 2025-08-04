//
//  AlternatesPopoutView.swift
//  Keyboard
//
//  Created by Claude on 8/1/25.
//

import UIKit

class AlternatesPopoutView: UIView {
    private var alternateKeys: [String] = []
    private var alternateKeyViews: [UIView] = []
    private var selectedIndex: Int? = nil
    private var originalKeyData: KeyData
    private var containerView: UIView
    private var deviceLayout: DeviceLayout
    private var onAlternateSelected: ((String) -> Void)?
    private var onDismiss: (() -> Void)?

    // X-coordinate centers for each alternate key for selection calculation
    private var alternateXCenters: [CGFloat] = []

    // Selection background layers
    private var selectionLayers: [CAShapeLayer] = []

    init(keyData: KeyData, alternates: [String], containerView: UIView, deviceLayout: DeviceLayout, onAlternateSelected: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.originalKeyData = keyData
        self.alternateKeys = alternates
        self.containerView = containerView
        self.deviceLayout = deviceLayout
        self.onAlternateSelected = onAlternateSelected
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        createIndividualPopouts()

        // Default select the first alternate (original character) - no animation
        selectedIndex = 0
        updateKeyAppearance(at: 0, selected: true)
    }

    private func createIndividualPopouts() {
        // Create individual KeyPopoutView-style popouts for each alternate
        // Position them side by side, fanning based on keyboard side

        let keyCenter = CGPoint(x: originalKeyData.frame.midX, y: originalKeyData.frame.midY)
        let alternateKeyWidth = deviceLayout.alternateKeyWidth
        let popoutTopWidth = deviceLayout.popoutBaseWidth
        let popoutHeight = deviceLayout.popoutHeight
        let keyWidth = originalKeyData.frame.width

        // Calculate total width: first character centered, remaining at alternateKeyWidth intervals
        let totalWidth: CGFloat
        if alternateKeys.count == 1 {
            totalWidth = popoutTopWidth
        } else {
            // Width from center of first character to center of last character, plus matching margins
            totalWidth = popoutTopWidth/2 + CGFloat(alternateKeys.count - 1) * alternateKeyWidth + popoutTopWidth/2
        }
        let popoutY = keyCenter.y - popoutHeight - deviceLayout.popupToKeyOffset

        // Determine which side of the keyboard this key is on
        let containerWidth = containerView.bounds.width
        let keyIsOnLeftHalf = keyCenter.x < containerWidth / 2

        // Calculate horizontal positioning based on keyboard side
        let startX: CGFloat
        if keyIsOnLeftHalf {
            // Left half: fan out to the right (align first popout with key center)
            startX = keyCenter.x - popoutTopWidth / 2
        } else {
            // Right half: fan out to the left (align last popout with key center)
            startX = keyCenter.x - totalWidth + popoutTopWidth / 2
        }

        // Ensure the popout doesn't go off-screen
        let adjustedStartX = max(0, min(startX, containerWidth - totalWidth))

        frame = CGRect(x: adjustedStartX, y: popoutY, width: totalWidth, height: popoutHeight)

        // Create ONE unified background shape
        // Create unified shape using PopoutView
        let theme = ColorTheme.current(for: containerView.traitCollection)

        let funnelSide: FunnelSide = keyIsOnLeftHalf ? .left : .right
        let shapeLayer = PopoutView.createShape(
            totalWidth: totalWidth,
            height: popoutHeight,
            keyWidth: keyWidth,
            deviceLayout: deviceLayout,
            theme: theme,
            funnelSide: funnelSide
        )

        layer.addSublayer(shapeLayer)

        // Create individual text labels over the unified shape
        for (index, alternate) in alternateKeys.enumerated() {
            // Calculate visual position - reverse positions for right half keys
            let visualIndex = keyIsOnLeftHalf ? index : alternateKeys.count - 1 - index

            // Calculate section position and width: first centered, rest at alternateKeyWidth intervals
            let (sectionX, sectionWidth): (CGFloat, CGFloat)
            if visualIndex == 0 {
                // First character: centered with full width
                sectionX = 0
                sectionWidth = popoutTopWidth
            } else {
                // Remaining characters: positioned at alternateKeyWidth intervals from center of first
                sectionX = popoutTopWidth/2 + CGFloat(visualIndex) * alternateKeyWidth - alternateKeyWidth/2
                sectionWidth = alternateKeyWidth
            }

            let labelHeight = popoutHeight - deviceLayout.funnelHeight // All labels at same height

            let labelView = UIView()
            labelView.frame = CGRect(x: sectionX, y: 0, width: sectionWidth, height: labelHeight)
            labelView.backgroundColor = .clear
            labelView.isUserInteractionEnabled = true
            labelView.tag = index

            let label = UILabel()
            label.text = alternate
            label.textColor = ColorTheme.current(for: containerView.traitCollection).textColor
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: deviceLayout.popoutFontSize, weight: .regular)

            // Position text at same level for all alternates
            let textCenterY = (labelHeight + deviceLayout.funnelHeight) * deviceLayout.popoutTextVerticalRatio

            labelView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: labelView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: labelView.topAnchor, constant: textCenterY)
            ])

            addSubview(labelView)
            alternateKeyViews.append(labelView)

            // Store the x-center for this alternate in container coordinates
            let centerInContainer = CGPoint(x: adjustedStartX + sectionX + sectionWidth/2, y: 0)
            alternateXCenters.append(centerInContainer.x)

            // Create selection background layer for this alternate
            let selectionLayer = CAShapeLayer()
            selectionLayer.isHidden = true
            labelView.layer.insertSublayer(selectionLayer, at: 0) // Insert behind text in the labelView
            selectionLayers.append(selectionLayer)
        }
    }


    func updateSelection(at point: CGPoint) {
        // Check if touch is outside keyboard bounds - if so, dismiss the popout
        let keyboardBounds = containerView.bounds
        if !keyboardBounds.contains(point) {
            dismiss()
            return
        }

        // Always select the closest alternate based on x-coordinate
        guard !alternateXCenters.isEmpty else { return }

        var closestIndex = 0
        var closestDistance = abs(point.x - alternateXCenters[0])

        for (index, xCenter) in alternateXCenters.enumerated() {
            let distance = abs(point.x - xCenter)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }

        let newSelectedIndex = closestIndex

        // Update visual selection
        if newSelectedIndex != selectedIndex {
            // Deselect previous
            if let oldIndex = selectedIndex {
                updateKeyAppearance(at: oldIndex, selected: false)
            }

            // Select new
            updateKeyAppearance(at: newSelectedIndex, selected: true)
            selectedIndex = newSelectedIndex
        }
    }

    private func updateKeyAppearance(at index: Int, selected: Bool) {
        guard index < alternateKeyViews.count && index < selectionLayers.count else {
            return
        }

        let popoutView = alternateKeyViews[index]
        let selectionLayer = selectionLayers[index]
        let theme = ColorTheme.current(for: containerView.traitCollection)

        // Get the label from the popout
        guard let label = popoutView.subviews.first as? UILabel else { return }

        if selected {
            // Disable implicit animations for instant snapping
            CATransaction.begin()
            CATransaction.setDisableActions(true)

            // Create blue rounded rectangle background
            let horizontalPadding: CGFloat = 2
            let verticalPadding: CGFloat = 6

            // Always use alternateKeyWidth for consistent selection indicator width
            let selectionWidth = deviceLayout.alternateKeyWidth - 2 * horizontalPadding
            let selectionRect = CGRect(
                x: (popoutView.frame.width - selectionWidth) / 2, // Center horizontally
                y: verticalPadding,
                width: selectionWidth,
                height: popoutView.frame.height - 2 * verticalPadding
            )

            let cornerRadius: CGFloat = 4
            let path = UIBezierPath(roundedRect: selectionRect, cornerRadius: cornerRadius)

            selectionLayer.path = path.cgPath
            selectionLayer.fillColor = theme.selectionColor.cgColor
            selectionLayer.strokeColor = UIColor.clear.cgColor
            selectionLayer.isHidden = false

            CATransaction.commit()
        } else {
            // Disable implicit animations for instant hiding
            CATransaction.begin()
            CATransaction.setDisableActions(true)

            // Hide selection background
            selectionLayer.isHidden = true

            CATransaction.commit()
        }
    }

    func selectCurrentAlternate() {
        if let index = selectedIndex, index < alternateKeys.count {
            let selectedAlternate = alternateKeys[index]
            onAlternateSelected?(selectedAlternate)
        }
        onDismiss?()
    }

    func dismiss() {
        // Clean up selection layers
        for selectionLayer in selectionLayers {
            selectionLayer.removeFromSuperlayer()
        }
        selectionLayers.removeAll()

        onDismiss?()
    }

    func hasValidSelection() -> Bool {
        return selectedIndex != nil
    }
}

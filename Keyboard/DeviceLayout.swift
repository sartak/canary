//
//  DeviceLayout.swift
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
    let cornerRadius: CGFloat
    let chevronSize: CGFloat
    let regularFontSize: CGFloat
    let specialFontSize: CGFloat
    let smallFontSize: CGFloat

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
        let baseBottomPadding: CGFloat = baseVerticalGap / 2
        let baseCornerRadius: CGFloat = 5
        let baseChevronSize: CGFloat = 16
        let baseRegularFontSize: CGFloat = 22
        let baseSpecialFontSize: CGFloat = 16
        let baseSmallFontSize: CGFloat = 12

        // Font scaling should be more conservative than UI scaling
        // Different scaling rates for different font types
        let regularFontScale = 1.0 + (widthScale - 1.0) * 0.15  // Letter keys scale slower
        let specialFontScale = 1.0 + (widthScale - 1.0) * 0.25  // Special keys scale slightly more
        let cornerRadiusScale = 1.0 + (widthScale - 1.0) * 0.2  // Corner radius scales conservatively
        let topPaddingScale = 1.0 + (heightScale - 1.0) * 0.3  // Top padding scales conservatively
        let gapScale = 1.0 + (widthScale - 1.0) * 0.2  // Gaps scale conservatively

        let layout = DeviceLayout(
            alphaKeyWidth: baseAlphaKeyWidth * widthScale,
            horizontalGap: baseHorizontalGap * gapScale,
            verticalGap: baseVerticalGap * gapScale,
            keyHeight: baseKeyHeight * heightScale,
            splitWidth: baseSplitWidth * widthScale,
            topPadding: baseTopPadding * topPaddingScale,
            bottomPadding: baseBottomPadding * heightScale,
            cornerRadius: baseCornerRadius * cornerRadiusScale,
            chevronSize: baseChevronSize * specialFontScale,
            regularFontSize: baseRegularFontSize * regularFontScale,
            specialFontSize: baseSpecialFontSize * specialFontScale,
            smallFontSize: baseSmallFontSize * specialFontScale
        )

        return layout
    }

    func totalKeyboardHeight(for layer: Layer, shifted: Bool, layout: KeyboardLayout, needsGlobe: Bool) -> CGFloat {
        let numberOfRows = CGFloat(layout.rows(for: layer, shifted: shifted, needsGlobe: needsGlobe).count)
        // topPadding + rows + gaps between rows + bottomPadding
        return topPadding + (numberOfRows * keyHeight) + ((numberOfRows - 1) * verticalGap) + bottomPadding
    }
}

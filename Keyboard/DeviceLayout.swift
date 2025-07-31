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

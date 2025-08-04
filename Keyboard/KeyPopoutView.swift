//
//  KeyPopoutView.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

class KeyPopoutView {
    static func createPopout(for keyData: KeyData, shiftState: ShiftState, containerView: UIView, traitCollection: UITraitCollection, deviceLayout: DeviceLayout) -> UIView {
        let popoutTopWidth = deviceLayout.popoutBaseWidth
        let popoutHeight = deviceLayout.popoutHeight
        let popoutFontSize = deviceLayout.popoutFontSize
        let keyWidth = keyData.frame.width

        let popout = UIView()
        popout.backgroundColor = .clear
        popout.isUserInteractionEnabled = false

        // Create popout shape using shared renderer
        let theme = ColorTheme.current(for: traitCollection)
        let shapeLayer = PopoutView.createShape(
            totalWidth: popoutTopWidth,
            height: popoutHeight,
            keyWidth: keyWidth,
            deviceLayout: deviceLayout,
            theme: theme,
            funnelSide: .left
        )

        popout.layer.addSublayer(shapeLayer)

        // Create content view using shared renderer
        let contentView = SFSymbolRenderer.createContentView(
            for: keyData.key,
            shiftState: shiftState,
            fontSize: popoutFontSize,
            theme: theme
        )

        popout.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Set up constraints based on content type
        if contentView is UIImageView {
            NSLayoutConstraint.activate([
                contentView.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                contentView.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * deviceLayout.popoutTextVerticalRatio),
                contentView.widthAnchor.constraint(equalToConstant: popoutFontSize),
                contentView.heightAnchor.constraint(equalToConstant: popoutFontSize)
            ])
        } else {
            NSLayoutConstraint.activate([
                contentView.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                contentView.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * deviceLayout.popoutTextVerticalRatio)
            ])
        }

        // Position popout above the key (always centered)
        let keyCenter = CGPoint(x: keyData.frame.midX, y: keyData.frame.midY)
        let popoutX = keyCenter.x - popoutTopWidth / 2

        popout.frame = CGRect(
            x: popoutX,
            y: keyCenter.y - popoutHeight - deviceLayout.popupToKeyOffset,
            width: popoutTopWidth,
            height: popoutHeight
        )

        return popout
    }
}

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

        let label = UILabel()
        label.textColor = theme.textColor
        label.textAlignment = .center

        // Check if key should use SF Symbol
        if let symbolName = keyData.key.sfSymbolName(shiftState: shiftState) {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: popoutFontSize, weight: .light)
            if let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig) {
                // Use SF Symbol as image
                let imageView = UIImageView(image: symbolImage.withTintColor(theme.textColor, renderingMode: .alwaysOriginal))
                imageView.contentMode = .scaleAspectFit

                popout.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * deviceLayout.popoutTextVerticalRatio),
                    imageView.widthAnchor.constraint(equalToConstant: popoutFontSize),
                    imageView.heightAnchor.constraint(equalToConstant: popoutFontSize)
                ])
            } else {
                // Fallback to text if SF Symbol fails
                label.text = keyData.key.label(shiftState: shiftState)
                label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)

                popout.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * deviceLayout.popoutTextVerticalRatio)
                ])
            }
        } else {
            // Use regular text
            label.text = keyData.key.label(shiftState: shiftState)
            label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)

            popout.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * deviceLayout.popoutTextVerticalRatio)
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

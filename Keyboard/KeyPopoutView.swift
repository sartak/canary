//
//  KeyPopoutView.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let basePopoutFontSize: CGFloat = 44

class KeyPopoutView {

    static func createPopout(for keyData: KeyData, shiftState: ShiftState, containerView: UIView, traitCollection: UITraitCollection) -> UIView {
        // Scale popout size based on device layout like keys
        let basePopoutTopWidth: CGFloat = 45
        let basePopoutHeight: CGFloat = 55
        let screenBounds = UIScreen.main.bounds
        let isLandscape = screenBounds.width > screenBounds.height
        let effectiveWidth = containerView.bounds.width
        let effectiveHeight = isLandscape ? screenBounds.width : screenBounds.height
        let referenceWidth: CGFloat = 402
        let referenceHeight: CGFloat = 874
        let widthScale = effectiveWidth / referenceWidth
        let heightScale = effectiveHeight / referenceHeight

        let popoutTopWidth = basePopoutTopWidth * widthScale
        let popoutHeight = basePopoutHeight * heightScale
        let popoutFontSize = basePopoutFontSize * widthScale
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

        let theme = ColorTheme.current(for: traitCollection)
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = theme.primaryKeyColor.cgColor
        shapeLayer.shadowColor = theme.shadowColor.cgColor
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
        label.textColor = theme.textColor
        label.textAlignment = .center

        // Check if key should use SF Symbol
        if let symbolName = keyData.keyType.sfSymbolName(shiftState: shiftState) {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: popoutFontSize, weight: .light)
            if let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig) {
                // Use SF Symbol as image
                let imageView = UIImageView(image: symbolImage.withTintColor(theme.textColor, renderingMode: .alwaysOriginal))
                imageView.contentMode = .scaleAspectFit

                popout.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * 0.35),
                    imageView.widthAnchor.constraint(equalToConstant: popoutFontSize),
                    imageView.heightAnchor.constraint(equalToConstant: popoutFontSize)
                ])
            } else {
                // Fallback to text if SF Symbol fails
                label.text = keyData.keyType.label(shiftState: shiftState)
                label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)

                popout.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * 0.35)
                ])
            }
        } else {
            // Use regular text
            label.text = keyData.keyType.label(shiftState: shiftState)
            label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)

            popout.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * 0.35)
            ])
        }

        // Position popout above the key (always centered)
        let keyCenter = CGPoint(x: keyData.frame.midX, y: keyData.frame.midY)
        let popoutX = keyCenter.x - popoutTopWidth / 2

        popout.frame = CGRect(
            x: popoutX,
            y: keyCenter.y - popoutHeight - 10,
            width: popoutTopWidth,
            height: popoutHeight
        )

        return popout
    }
}

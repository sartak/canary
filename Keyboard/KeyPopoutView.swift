//
//  KeyPopoutView.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/29/25.
//

import UIKit

private let primaryKeyColor = UIColor(white: 115/255.0, alpha: 1.0)
private let popoutFontSize: CGFloat = 44

class KeyPopoutView {

    static func createPopout(for keyData: KeyData, shifted: Bool, containerView: UIView) -> UIView {
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
        label.text = keyData.keyType.label(shifted: shifted)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: popoutFontSize, weight: .regular)
        label.textAlignment = .center

        popout.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: popout.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: popout.topAnchor, constant: popoutHeight * 0.35)
        ])

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

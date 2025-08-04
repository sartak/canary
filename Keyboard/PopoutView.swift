//
//  PopoutView.swift
//  Keyboard
//
//  Created by Claude on 8/3/25.
//

import UIKit

enum FunnelSide {
    case left
    case right
}

class PopoutView {
    static func createShape(
        totalWidth: CGFloat,
        height: CGFloat,
        keyWidth: CGFloat,
        deviceLayout: DeviceLayout,
        theme: ColorTheme,
        funnelSide: FunnelSide
    ) -> CAShapeLayer {
        let shapeLayer = createPrimaryShape(
            totalWidth: totalWidth,
            height: height,
            keyWidth: keyWidth,
            deviceLayout: deviceLayout,
            theme: theme,
            funnelSide: funnelSide
        )

        let shadowPath = createShadowPath(
            totalWidth: totalWidth,
            height: height,
            keyWidth: keyWidth,
            deviceLayout: deviceLayout,
            funnelSide: funnelSide
        )

        shapeLayer.shadowPath = shadowPath.cgPath
        return shapeLayer
    }

    private static func createPrimaryShape(
        totalWidth: CGFloat,
        height: CGFloat,
        keyWidth: CGFloat,
        deviceLayout: DeviceLayout,
        theme: ColorTheme,
        funnelSide: FunnelSide
    ) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        let path = UIBezierPath()
        let cornerRadius = deviceLayout.cornerRadius
        let funnelHeight = deviceLayout.funnelHeight
        let popoutBaseWidth = deviceLayout.popoutBaseWidth

        path.move(to: CGPoint(x: cornerRadius, y: 0))

        path.addLine(to: CGPoint(x: totalWidth - cornerRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: totalWidth, y: cornerRadius), controlPoint: CGPoint(x: totalWidth, y: 0))

        if totalWidth > popoutBaseWidth {
            if funnelSide == .left {
                path.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight - cornerRadius))
                path.addQuadCurve(to: CGPoint(x: totalWidth - cornerRadius, y: height - funnelHeight), controlPoint: CGPoint(x: totalWidth, y: height - funnelHeight))
            } else {
                path.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight))
            }
        } else {
            path.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight))
        }

        let funnelStartX = max(0, (popoutBaseWidth - keyWidth) / 2)
        let funnelEndX = popoutBaseWidth - funnelStartX
        let controlY = height - 5
        let controlInset: CGFloat = 8

        if funnelSide == .left {
            path.addLine(to: CGPoint(x: popoutBaseWidth, y: height - funnelHeight))

            path.addQuadCurve(to: CGPoint(x: funnelEndX, y: height),
                             controlPoint: CGPoint(x: popoutBaseWidth - controlInset, y: controlY))
            path.addLine(to: CGPoint(x: funnelStartX, y: height))
            path.addQuadCurve(to: CGPoint(x: 0, y: height - funnelHeight),
                             controlPoint: CGPoint(x: controlInset, y: controlY))
        } else {
            let offset = totalWidth - popoutBaseWidth
            path.addLine(to: CGPoint(x: offset + popoutBaseWidth, y: height - funnelHeight))

            path.addQuadCurve(to: CGPoint(x: offset + funnelEndX, y: height),
                             controlPoint: CGPoint(x: offset + popoutBaseWidth - controlInset, y: controlY))
            path.addLine(to: CGPoint(x: offset + funnelStartX, y: height))
            path.addQuadCurve(to: CGPoint(x: offset, y: height - funnelHeight),
                             controlPoint: CGPoint(x: offset + controlInset, y: controlY))
            if funnelSide == .right && totalWidth > popoutBaseWidth {
                path.addLine(to: CGPoint(x: cornerRadius, y: height - funnelHeight))
                path.addQuadCurve(to: CGPoint(x: 0, y: height - funnelHeight - cornerRadius), controlPoint: CGPoint(x: 0, y: height - funnelHeight))
            } else {
                path.addLine(to: CGPoint(x: 0, y: height - funnelHeight))
            }
        }

        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        path.close()

        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = theme.primaryKeyColor.cgColor
        shapeLayer.shadowColor = theme.shadowColor.cgColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 3

        return shapeLayer
    }

    private static func createShadowPath(
        totalWidth: CGFloat,
        height: CGFloat,
        keyWidth: CGFloat,
        deviceLayout: DeviceLayout,
        funnelSide: FunnelSide
    ) -> UIBezierPath {
        let shadowPath = UIBezierPath()
        let cornerRadius = deviceLayout.cornerRadius
        let funnelHeight = deviceLayout.funnelHeight
        let popoutBaseWidth = deviceLayout.popoutBaseWidth
        let controlY = height - 5
        let controlInset: CGFloat = 8

        let funnelStartX = max(0, (popoutBaseWidth - keyWidth) / 2)
        let funnelEndX = popoutBaseWidth - funnelStartX

        shadowPath.move(to: CGPoint(x: cornerRadius, y: 0))
        shadowPath.addLine(to: CGPoint(x: totalWidth - cornerRadius, y: 0))
        shadowPath.addQuadCurve(to: CGPoint(x: totalWidth, y: cornerRadius), controlPoint: CGPoint(x: totalWidth, y: 0))
        if totalWidth > popoutBaseWidth {
            if funnelSide == .left {
                shadowPath.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight - cornerRadius))
                shadowPath.addQuadCurve(to: CGPoint(x: totalWidth - cornerRadius, y: height - funnelHeight), controlPoint: CGPoint(x: totalWidth, y: height - funnelHeight))
            } else {
                shadowPath.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight))
            }
        } else {
            shadowPath.addLine(to: CGPoint(x: totalWidth, y: height - funnelHeight))
        }

        if funnelSide == .left {
            shadowPath.addLine(to: CGPoint(x: funnelEndX, y: height - funnelHeight))
            shadowPath.addQuadCurve(to: CGPoint(x: funnelEndX, y: height),
                                   controlPoint: CGPoint(x: popoutBaseWidth - controlInset, y: controlY))
            shadowPath.move(to: CGPoint(x: funnelStartX, y: height))
            shadowPath.addQuadCurve(to: CGPoint(x: 0, y: height - funnelHeight),
                                   controlPoint: CGPoint(x: controlInset, y: controlY))
        } else {
            let offset = totalWidth - popoutBaseWidth
            shadowPath.addLine(to: CGPoint(x: offset + funnelEndX, y: height - funnelHeight))
            shadowPath.addQuadCurve(to: CGPoint(x: offset + funnelEndX, y: height),
                                   controlPoint: CGPoint(x: offset + popoutBaseWidth - controlInset, y: controlY))
            shadowPath.move(to: CGPoint(x: offset + funnelStartX, y: height))
            shadowPath.addQuadCurve(to: CGPoint(x: offset, y: height - funnelHeight),
                                   controlPoint: CGPoint(x: offset + controlInset, y: controlY))
        }

        if funnelSide == .right {
            shadowPath.move(to: CGPoint(x: 0, y: height - funnelHeight))
        }
        shadowPath.addLine(to: CGPoint(x: 0, y: cornerRadius))
        shadowPath.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        shadowPath.close()

        return shadowPath
    }
}

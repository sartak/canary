//
//  ColorTheme.swift
//  Keyboard
//
//  Created by Shawn Moore on 7/31/25.
//

import UIKit

enum ColorTheme {
    case dark
    case light

    static func current(for traitCollection: UITraitCollection) -> ColorTheme {
        if traitCollection.userInterfaceStyle == .dark {
            return .dark
        } else {
            return .light
        }
    }

    var primaryKeyColor: UIColor {
        switch self {
        case .dark:
            return UIColor(white: 115/255.0, alpha: 1.0)
        case .light:
            return UIColor.white
        }
    }

    var secondaryKeyColor: UIColor {
        switch self {
        case .dark:
            return UIColor(white: 63/255.0, alpha: 1.0)
        case .light:
            return UIColor(red: 171/255.0, green: 176/255.0, blue: 186/255.0, alpha: 1.0)
        }
    }

    var textColor: UIColor {
        switch self {
        case .dark:
            return .white
        case .light:
            return .black
        }
    }

    var shadowColor: UIColor {
        switch self {
        case .dark:
            return .black
        case .light:
            return UIColor.black.withAlphaComponent(0.1)
        }
    }

    var keyShadowColor: UIColor {
        switch self {
        case .dark:
            return UIColor.black.withAlphaComponent(0.4)
        case .light:
            return UIColor.black.withAlphaComponent(0.25)
        }
    }

    var keyShadowOffset: CGSize {
        return CGSize(width: 0, height: 2)
    }

    var keyShadowRadius: CGFloat {
        return 0.5
    }

    var decorationColor: UIColor {
        switch self {
        case .dark:
            return primaryKeyColor
        case .light:
            return .black
        }
    }
}

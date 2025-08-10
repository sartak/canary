//
//  AutocorrectPopoutView.swift
//  Keyboard
//
//  Created by Claude on 8/7/25.
//

import UIKit

class AutocorrectPopoutView: UIView {
    private let originalWord: String
    private let correctedWord: String
    private let deviceLayout: DeviceLayout
    private let theme: ColorTheme

    private var originalLabel: UILabel!
    private var arrowLabel: UILabel!
    private var correctedLabel: UILabel!
    private var backgroundShape: CAShapeLayer!

    init(originalWord: String, correctedWord: String, deviceLayout: DeviceLayout, traitCollection: UITraitCollection) {
        self.originalWord = originalWord
        self.correctedWord = correctedWord
        self.deviceLayout = deviceLayout
        self.theme = ColorTheme.current(for: traitCollection)

        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = UIColor.clear

        // Create background shape layer
        backgroundShape = CAShapeLayer()
        backgroundShape.fillColor = theme.autocorrectColor.cgColor
        backgroundShape.shadowColor = theme.shadowColor.cgColor
        backgroundShape.shadowOffset = CGSize(width: 0, height: 2)
        backgroundShape.shadowRadius = 4
        backgroundShape.shadowOpacity = 0.3
        layer.addSublayer(backgroundShape)

        // Create labels
        originalLabel = createLabel(text: originalWord, color: theme.textColor)
        arrowLabel = createLabel(text: "→", color: theme.textColor)
        correctedLabel = createLabel(text: correctedWord, color: theme.textColor)

        addSubview(originalLabel)
        addSubview(arrowLabel)
        addSubview(correctedLabel)

        setupConstraints()
    }

    private func createLabel(text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = UIFont.systemFont(ofSize: deviceLayout.regularFontSize * 0.8, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupConstraints() {
        let padding: CGFloat = 8
        let spacing: CGFloat = 4

        NSLayoutConstraint.activate([
            // Original word on the left
            originalLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            originalLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Arrow in the middle
            arrowLabel.leadingAnchor.constraint(equalTo: originalLabel.trailingAnchor, constant: spacing),
            arrowLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Corrected word on the right
            correctedLabel.leadingAnchor.constraint(equalTo: arrowLabel.trailingAnchor, constant: spacing),
            correctedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            correctedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Height constraints
            originalLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            originalLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding),
            arrowLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            arrowLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding),
            correctedLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            correctedLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBackgroundShape()
    }

    private func updateBackgroundShape() {
        let cornerRadius: CGFloat = 8
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        backgroundShape.path = path.cgPath
        backgroundShape.frame = bounds
    }

    func show(at position: CGPoint, in containerView: UIView, duration: TimeInterval = 1.2) {
        // Size the popout to fit content
        let size = calculateSize()
        frame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height - 10,
            width: size.width,
            height: size.height
        )

        // Ensure popout stays within container bounds
        let minX = max(8, frame.minX)
        let maxX = min(containerView.bounds.width - frame.width - 8, frame.minX)
        frame.origin.x = min(maxX, minX)

        containerView.addSubview(self)

        // Animate appearance
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut]) {
                self.transform = .identity
            } completion: { _ in
                // Auto-dismiss after showing the transformation
                UIView.animate(withDuration: 0.3, delay: duration - 0.5, options: [.curveEaseIn]) {
                    self.alpha = 0
                    self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                } completion: { _ in
                    self.removeFromSuperview()
                }
            }
        }
    }

    private func calculateSize() -> CGSize {
        let padding: CGFloat = 8
        let spacing: CGFloat = 4

        let originalSize = originalLabel.intrinsicContentSize
        let arrowSize = arrowLabel.intrinsicContentSize
        let correctedSize = correctedLabel.intrinsicContentSize

        let width = originalSize.width + arrowSize.width + correctedSize.width + (padding * 2) + (spacing * 2)
        let height = max(originalSize.height, max(arrowSize.height, correctedSize.height)) + (padding * 2)

        return CGSize(width: width, height: height)
    }

    static func showAutocorrection(from originalWord: String, to correctedWord: String, at position: CGPoint, in containerView: UIView, deviceLayout: DeviceLayout, traitCollection: UITraitCollection) {
        let popout = AutocorrectPopoutView(
            originalWord: originalWord,
            correctedWord: correctedWord,
            deviceLayout: deviceLayout,
            traitCollection: traitCollection
        )
        popout.show(at: position, in: containerView)
    }
}

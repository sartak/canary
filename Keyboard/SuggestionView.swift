import UIKit

class SuggestionView: UIView, SuggestionServiceDelegate {
    private var deviceLayout: DeviceLayout

    private var typeaheads: [(String, [InputAction])] = []
    private var onTypeaheadTapped: (([InputAction]) -> Void)?

    private var autocorrectWord: String?

    private var scrollView: UIScrollView!

    init(deviceLayout: DeviceLayout) {
        self.deviceLayout = deviceLayout
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.maximumZoomScale = 1.0
        scrollView.minimumZoomScale = 1.0
        addSubview(scrollView)
    }

    func setOnTypeaheadTapped(_ onTapped: @escaping ([InputAction]) -> Void) {
        self.onTypeaheadTapped = onTapped
    }

    private func createButton(title: String, textColor: UIColor, target: Selector, leftPadding: CGFloat, rightPadding: CGFloat, x: CGFloat, y: CGFloat, height: CGFloat) -> UIButton {
        var config = UIButton.Configuration.plain()

        config.title = title
        config.baseForegroundColor = textColor
        config.titleAlignment = .leading

        let button = UIButton(configuration: config)
        button.addTarget(self, action: target, for: .touchUpInside)

        // Calculate button width based on text content plus padding
        let font = UIFont.systemFont(ofSize: deviceLayout.suggestionFontSize)
        let textSize = (title as NSString).size(withAttributes: [.font: font])

        // Add small buffer to prevent text truncation in UIButton
        let textBuffer: CGFloat = 4.0
        let width = textSize.width + leftPadding + rightPadding + textBuffer

        // Update button configuration with padding and font
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leftPadding, bottom: 0, trailing: rightPadding)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = font
            return outgoing
        }
        button.configuration = config

        button.frame = CGRect(x: x, y: y, width: width, height: height)
        return button
    }

    @objc private func typeaheadButtonTapped(_ sender: UIButton) {
        let buttonIndex = sender.tag
        guard buttonIndex < typeaheads.count else { return }
        let actions = typeaheads[buttonIndex].1
        onTypeaheadTapped?(actions)
    }

    @objc private func autocorrectButtonTapped(_ sender: UIButton) {
    }

    private func layoutSuggestions() {
        scrollView.contentOffset.x = 0

        // Clear existing UI completely
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        scrollView.layer.sublayers?.removeAll()

        var buttons: [UIButton] = []
        var currentX: CGFloat = 0
        let buttonHeight = deviceLayout.topPadding - deviceLayout.verticalGap
        let buttonY = (bounds.height - buttonHeight) / 2

        let theme = ColorTheme.current(for: traitCollection)

        // Create autocorrect button first if available
        if let correction = autocorrectWord {
            let button = createButton(title: correction, textColor: theme.autocorrectColor, target: #selector(autocorrectButtonTapped), leftPadding: 0, rightPadding: deviceLayout.suggestionGap, x: currentX, y: buttonY, height: buttonHeight)
            scrollView.addSubview(button)
            currentX += button.frame.width
            buttons.append(button)
        }

        // Create and layout buttons for each typeahead
        for (index, (label, _)) in typeaheads.enumerated() {
            // First button overall gets no left padding, otherwise normal padding
            let leftPadding = buttons.isEmpty ? 0 : deviceLayout.suggestionGap
            let button = createButton(title: label, textColor: theme.typeaheadTextColor, target: #selector(typeaheadButtonTapped), leftPadding: leftPadding, rightPadding: deviceLayout.suggestionGap, x: currentX, y: buttonY, height: buttonHeight)
            button.tag = index
            scrollView.addSubview(button)
            currentX += button.frame.width
            buttons.append(button)
        }

        // Create dividers between buttons
        if buttons.count > 1 {
            for i in 1..<buttons.count {
                let button = buttons[i - 1]
                let dividerLayer = CALayer()
                dividerLayer.backgroundColor = theme.suggestionDividerColor.cgColor
                dividerLayer.frame = CGRect(x: button.frame.maxX, y: buttonY, width: 0.5, height: buttonHeight)
                scrollView.layer.addSublayer(dividerLayer)
            }
        }

        // Set scroll view content size
        scrollView.contentSize = CGSize(width: currentX, height: bounds.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        layoutSuggestions()
    }

    // MARK: - SuggestionServiceDelegate

    func suggestionService(_ service: SuggestionService, didUpdateSuggestions typeahead: [(String, [InputAction])], autocorrect: String?) {
        self.typeaheads = typeahead
        self.autocorrectWord = autocorrect
        layoutSuggestions()
    }
}

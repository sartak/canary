import UIKit

class SuggestionView: UIView, SuggestionServiceDelegate {
    private var deviceLayout: DeviceLayout

    private var typeaheads: [(String, [InputAction])] = []
    private var onTypeaheadTapped: (([InputAction]) -> Void)?

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

    private func createTypeaheadButton(label: String, actions: [InputAction]) -> UIButton {
        var config = UIButton.Configuration.plain()
        let theme = ColorTheme.current(for: traitCollection)

        config.title = label
        config.baseForegroundColor = theme.typeaheadTextColor
        config.titleAlignment = .leading
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: self.deviceLayout.suggestionFontSize)
            return outgoing
        }

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(typeaheadButtonTapped), for: .touchUpInside)

        return button
    }

    @objc private func typeaheadButtonTapped(_ sender: UIButton) {
        let buttonIndex = sender.tag
        guard buttonIndex < typeaheads.count else { return }
        let actions = typeaheads[buttonIndex].1
        onTypeaheadTapped?(actions)
    }

    private func layoutSuggestions() {
        scrollView.contentOffset.x = 0

        // Clear existing UI completely
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        scrollView.layer.sublayers?.removeAll()

        let theme = ColorTheme.current(for: traitCollection)
        var currentX: CGFloat = 0
        let buttonHeight = deviceLayout.topPadding - deviceLayout.verticalGap
        let buttonY = (bounds.height - buttonHeight) / 2

        // Create and layout buttons for each typeahead
        for (index, (label, actions)) in typeaheads.enumerated() {
            let button = createTypeaheadButton(label: label, actions: actions)
            button.tag = index
            scrollView.addSubview(button)

            // Calculate button width based on text content plus padding
            let text = button.configuration?.title ?? ""
            let textSize = (text as NSString).size(withAttributes: [
                .font: UIFont.systemFont(ofSize: deviceLayout.suggestionFontSize)
            ])

            // First button gets no left padding, others get normal padding
            let leftPadding = index == 0 ? 0 : deviceLayout.suggestionGap
            let rightPadding = deviceLayout.suggestionGap

            // Add small buffer to prevent text truncation in UIButton
            let textBuffer: CGFloat = 4.0
            let buttonWidth = textSize.width + leftPadding + rightPadding + textBuffer

            // Update button configuration with padding
            var config = button.configuration ?? UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leftPadding, bottom: 0, trailing: rightPadding)
            button.configuration = config

            button.frame = CGRect(x: currentX, y: buttonY, width: buttonWidth, height: buttonHeight)
            currentX += buttonWidth

            // Add divider line after each button except the last one
            if index < typeaheads.count - 1 {
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

    func suggestionService(_ service: SuggestionService, didUpdateTypeahead suggestions: [(String, [InputAction])]) {
        self.typeaheads = suggestions
        self.onTypeaheadTapped = onTypeaheadTapped ?? { _ in }
        layoutSuggestions()
    }
}

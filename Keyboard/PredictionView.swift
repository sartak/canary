import UIKit

class PredictionView: UIView {
    private var suggestions: [(String, [PredictionAction])] = []
    private var suggestionButtons: [UIButton] = []
    private var deviceLayout: DeviceLayout
    private var onSuggestionTapped: (([PredictionAction]) -> Void)?
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
        addSubview(scrollView)
    }

    func updateSuggestions(_ suggestions: [(String, [PredictionAction])], onTapped: @escaping ([PredictionAction]) -> Void) {
        self.suggestions = suggestions
        self.onSuggestionTapped = onTapped

        // Remove existing buttons
        suggestionButtons.forEach { $0.removeFromSuperview() }
        suggestionButtons.removeAll()

        // Create new buttons for each suggestion
        for (label, actions) in suggestions {
            let button = createSuggestionButton(label: label, actions: actions)
            scrollView.addSubview(button)
            suggestionButtons.append(button)
        }

        layoutSuggestionButtons()
    }

    private func createSuggestionButton(label: String, actions: [PredictionAction]) -> UIButton {
        let button = UIButton(type: .system)
        let theme = ColorTheme.current(for: traitCollection)

        button.setTitle(label, for: .normal)
        button.setTitleColor(theme.predictionTextColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: deviceLayout.predictionFontSize)
        button.addTarget(self, action: #selector(suggestionButtonTapped), for: .touchUpInside)

        // Store the actions in the button's tag (we'll use a lookup approach)
        let buttonIndex = suggestionButtons.count
        button.tag = buttonIndex

        return button
    }

    @objc private func suggestionButtonTapped(_ sender: UIButton) {
        let buttonIndex = sender.tag
        guard buttonIndex < suggestions.count else { return }
        let actions = suggestions[buttonIndex].1
        onSuggestionTapped?(actions)
    }

    private func layoutSuggestionButtons() {
        guard !suggestionButtons.isEmpty else { return }

        var currentX: CGFloat = 0
        let buttonHeight = bounds.height

        for (index, button) in suggestionButtons.enumerated() {
            // Calculate button width based on text content
            let text = button.title(for: .normal) ?? ""
            let textSize = (text as NSString).size(withAttributes: [
                .font: UIFont.systemFont(ofSize: deviceLayout.predictionFontSize)
            ])

            button.frame = CGRect(x: currentX, y: 0, width: textSize.width, height: buttonHeight)
            currentX += textSize.width

            // Add gap after each button except the last one
            if index < suggestionButtons.count - 1 {
                currentX += deviceLayout.predictionGap
            }
        }

        // Set scroll view content size
        scrollView.contentSize = CGSize(width: currentX, height: buttonHeight)

        // Add dividing lines
        addDividingLines()
    }

    private func addDividingLines() {
        // Remove existing dividing lines
        scrollView.layer.sublayers?.removeAll { $0.name == "dividing-line" }

        guard suggestionButtons.count > 1 else { return }

        let theme = ColorTheme.current(for: traitCollection)

        for i in 0..<(suggestionButtons.count - 1) {
            let button = suggestionButtons[i]
            let lineX = button.frame.maxX + deviceLayout.predictionGap / 2

            let dividerLayer = CALayer()
            dividerLayer.name = "dividing-line"
            dividerLayer.backgroundColor = theme.predictionDividerColor.cgColor
            dividerLayer.frame = CGRect(x: lineX, y: 0, width: 0.5, height: bounds.height)

            scrollView.layer.addSublayer(dividerLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        layoutSuggestionButtons()
    }
}

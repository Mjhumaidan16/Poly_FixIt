import UIKit

/// A simple "card" view that displays one availability slot.
///
/// UI layout:
/// - Left:  start time split across two lines ("9:00\nAM")
/// - Right: range ("9:00 AM - 11:00 AM") and hours ("2.0 Hours Available Slot")
final class AvailabilitySlotView: UIView {

    // MARK: - UI
    private let startOnlyLabel = UILabel()
    private let rangeLabel = UILabel()
    private let hoursLabel = UILabel()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    // MARK: - Setup
    private func buildUI() {
        // Card styling (matches the project look but uses system colors to stay readable).
        layer.cornerRadius = 10
        layer.masksToBounds = true
        backgroundColor = UIColor(red: 0.094, green: 0.153, blue: 0.259, alpha: 1.0)

        startOnlyLabel.numberOfLines = 2
        startOnlyLabel.textAlignment = .center
        startOnlyLabel.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        startOnlyLabel.textColor = .white

        rangeLabel.numberOfLines = 1
        rangeLabel.font = UIFont.systemFont(ofSize: 19, weight: .regular)
        rangeLabel.textColor = .white

        hoursLabel.numberOfLines = 1
        hoursLabel.font = UIFont.systemFont(ofSize: 19, weight: .regular)
        hoursLabel.textColor = .white

        // Right side container
        let rightPanel = UIView()
        rightPanel.backgroundColor = UIColor(red: 0.502, green: 0.553, blue: 0.643, alpha: 0.5)
        rightPanel.layer.cornerRadius = 15
        rightPanel.layer.masksToBounds = true

        let rightStack = UIStackView(arrangedSubviews: [rangeLabel, hoursLabel])
        rightStack.axis = .vertical
        rightStack.spacing = 6
        rightStack.alignment = .leading
        rightStack.distribution = .fill

        rightPanel.addSubview(rightStack)
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rightStack.topAnchor.constraint(equalTo: rightPanel.topAnchor, constant: 8),
            rightStack.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor, constant: -8),
            rightStack.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 20),
            rightStack.trailingAnchor.constraint(lessThanOrEqualTo: rightPanel.trailingAnchor, constant: -20)
        ])

        // Main layout
        let mainStack = UIStackView(arrangedSubviews: [startOnlyLabel, rightPanel])
        mainStack.axis = .horizontal
        mainStack.spacing = 15
        mainStack.alignment = .center
        mainStack.distribution = .fill

        addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),

            // Keep the start column similar to your storyboard spacing
            startOnlyLabel.widthAnchor.constraint(equalToConstant: 70),

            // Give the right panel a minimum height so it looks like your storyboard card
            rightPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 65)
        ])
    }

    // MARK: - Public
    func configure(startText: String, rangeText: String, hoursText: String) {
        startOnlyLabel.text = startText
        rangeLabel.text = rangeText
        hoursLabel.text = hoursText
    }
}

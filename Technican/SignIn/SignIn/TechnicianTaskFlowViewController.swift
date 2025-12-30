import UIKit

final class TechnicianTaskFlowViewController: UIViewController {

    // MARK: - Outlets (connect if needed)
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var noPartsSwitch: UISwitch!
    @IBOutlet weak var partsStackView: UIStackView!
    @IBOutlet weak var addPartButton: UIButton!
    @IBOutlet weak var confirmPartsButton: UIButton!

    // MARK: - Data
    var requestId: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    // MARK: - UI Setup
    private func configureUI() {
        navigationItem.title = "Inventory"

        confirmPartsButton.layer.cornerRadius = 8
        addPartButton.layer.cornerRadius = 8

        // Initial state
        togglePartsUI(isEnabled: !noPartsSwitch.isOn)
    }

    // MARK: - Actions
    @IBAction func noPartsSwitchChanged(_ sender: UISwitch) {
        togglePartsUI(isEnabled: !sender.isOn)
    }

    @IBAction func addPartTapped(_ sender: UIButton) {
        print("➕ Add part from inventory")
        // Later: present inventory picker
    }

    @IBAction func confirmPartsTapped(_ sender: UIButton) {
        print("✅ Confirm selected parts")
        // Later: save selected parts to Firestore
    }

    // MARK: - Helpers
    private func togglePartsUI(isEnabled: Bool) {
        partsStackView.alpha = isEnabled ? 1.0 : 0.4
        partsStackView.isUserInteractionEnabled = isEnabled
        addPartButton.isEnabled = isEnabled
        confirmPartsButton.isEnabled = isEnabled
    }
}

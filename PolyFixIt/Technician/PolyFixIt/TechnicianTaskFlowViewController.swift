import UIKit

final class TechnicianTaskFlowViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var noPartsSwitch: UISwitch!
    @IBOutlet weak var partsStackView: UIStackView!
    @IBOutlet weak var addPartButton: UIButton!
    @IBOutlet weak var confirmPartsButton: UIButton!

    var requestId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()

        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(barButtonTapped)
    }

    private func configureUI() {
        navigationItem.title = "Inventory"

        confirmPartsButton.layer.cornerRadius = 8
        addPartButton.layer.cornerRadius = 8

        togglePartsUI(isEnabled: !noPartsSwitch.isOn)
    }

    //  No segue needed
    @objc private func barButtonTapped() {
        guard let requestId else {
            print(" requestId is nil before navigation")
            return
        }

        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "TechViewRequestViewController") as? TechViewRequestViewController else {
            fatalError(" Could not instantiate TechViewRequestViewController. Check Storyboard ID.")
        }

        vc.requestId = requestId
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func noPartsSwitchChanged(_ sender: UISwitch) {
        togglePartsUI(isEnabled: !sender.isOn)
    }

    @IBAction func addPartTapped(_ sender: UIButton) {
        print("➕ Add part from inventory")
    }

    @IBAction func confirmPartsTapped(_ sender: UIButton) {
        print(" Confirm selected parts")
    }

    private func togglePartsUI(isEnabled: Bool) {
        partsStackView.alpha = isEnabled ? 1.0 : 0.4
        partsStackView.isUserInteractionEnabled = isEnabled
        addPartButton.isEnabled = isEnabled
        confirmPartsButton.isEnabled = isEnabled
    }
}

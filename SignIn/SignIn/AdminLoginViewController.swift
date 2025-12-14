import UIKit
import FirebaseAuth

class AdminLoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
//        statusLabel.text = ""
    }

    @IBAction func submitButtonTapped(_ sender: UIButton) {

        guard let email = emailTextField.text,
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {
            statusLabel.text = "Enter email and password"
            return
        }

        statusLabel.text = "Signing in..."

        Auth.auth().signIn(withEmail: email, password: password) { result, error in

            if let error = error {
                self.statusLabel.text = error.localizedDescription
                return
            }

            self.statusLabel.text = "Login successful"
            self.goToNextScreen()
        }
    }

    private func goToNextScreen() {
        print("Navigate to next screen")
    }
}

import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

final class ChatViewController: UIViewController {
    
    // MARK: - IBOutlets (Storyboard)
    @IBOutlet weak var messageStackView: UIStackView!
    @IBOutlet weak var messageSenderTemplate: UIView!
    @IBOutlet weak var messageRecevierTemplate: UIView!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var changeModeToTechnician: UIButton!
    
    // MARK: - Properties
    private let viewModel = ChatViewModel(mode: .ai)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureInitialState()
    }
    
    // MARK: - UI State
    private func configureInitialState() {
        changeModeToTechnician.isEnabled = false
        changeModeToTechnician.alpha = 0.5
    }
    
    private func updateTechnicianButtonState() {
        let enabled = viewModel.canSwitchToTechnicianChat()
        changeModeToTechnician.isEnabled = enabled
        changeModeToTechnician.alpha = enabled ? 1.0 : 0.5
    }
    
    // MARK: - Actions
    @IBAction func sendTapped(_ sender: UIButton) {
        guard let text = messageTextField.text, !text.isEmpty else { return }
        messageTextField.text = ""
        
        viewModel.sendUserMessage(text) { [weak self] in
            self?.reloadMessages()
        }
    }
    
    @IBAction func changeModeTapped(_ sender: UIButton) {
        viewModel.switchToTechnicianChat()
        reloadMessages()
    }
    
    // MARK: - Message Rendering
    private func reloadMessages() {
        messageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for message in viewModel.messages {
            let bubble = createBubble(for: message)
            messageStackView.addArrangedSubview(bubble)
        }
        
        updateTechnicianButtonState()
    }
    
    private func createBubble(for message: ChatMessage) -> UIView {
        
        let label = UILabel()
        label.numberOfLines = 0
        label.text = message.text
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.padding(top: 8, left: 12, bottom: 8, right: 12)
        
        switch message.sender {
        case .user:
            label.backgroundColor = .systemBlue
            label.textColor = .white
            label.textAlignment = .right
            
        case .ai:
            label.backgroundColor = .systemGray5
            label.textColor = .black
            label.textAlignment = .left
            
        case .system:
            label.backgroundColor = .clear
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            
        default:
            label.backgroundColor = .systemGray4
            label.textColor = .black
        }
        
        return label
    }
}

extension UILabel {

    func padding(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        let inset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        self.drawText(in: self.bounds.inset(by: inset))
    }
}


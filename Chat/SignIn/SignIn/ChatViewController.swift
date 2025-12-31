import UIKit
import FirebaseFirestore

final class ChatViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var messageStackView: UIStackView?
    @IBOutlet weak var messageTextField: UITextField?
    @IBOutlet weak var sendButton: UIButton?
    @IBOutlet weak var changeModeToTechnician: UIButton?

    // ✅ Make templates OPTIONAL so storyboard wiring issues don't crash
    @IBOutlet weak var messageSenderTemplate: UIView?
    @IBOutlet weak var messageRecvierrTemplate: UIView?

    // MARK: - Properties
    private let viewModel = ChatViewModel(mode: .ai)

    // NOTE: you hardcoded this id in the project
    var requestId: String = "jjo4TWHhY3Rag3PHncWX"
    private var requestData: [String: Any]?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureInitialState()

        if !requestId.isEmpty {
            fetchRequestData(for: requestId)
        }
    }

    private func configureInitialState() {
        changeModeToTechnician?.isEnabled = false
        changeModeToTechnician?.alpha = 0.5
    }

    private func updateTechnicianButtonState() {
        let enabled = viewModel.canSwitchToTechnicianChat()
        changeModeToTechnician?.isEnabled = enabled
        changeModeToTechnician?.alpha = enabled ? 1.0 : 0.5
    }

    // MARK: - Firestore
    private func fetchRequestData(for requestId: String) {
        let db = Firestore.firestore()
        let docRef = db.collection("requests").document(requestId)

        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Failed to fetch request data:", error)
                return
            }
            guard let data = snapshot?.data() else {
                print("⚠️ No request data found for id: \(requestId)")
                return
            }

            self.requestData = data

            Task { @MainActor in
                await self.sendInitialAIMessage()
            }
        }
    }

    @MainActor
    private func sendInitialAIMessage() async {
        guard let data = requestData else { return }

        let title = data["title"] as? String ?? "No title"
        let description = data["description"] as? String ?? "No description"
        let category = data["selectedCategory"] as? String ?? "General"
        let imageUrl = data["imageUrl"] as? String ?? ""

        let initialPrompt = """
        Request Data:
        - Title: \(title)
        - Description: \(description)
        - Category: \(category)
        - Image: \(imageUrl)

        Start the conversation following PolyFixIt AI workflow.
        """

        let aiReply = await viewModel.aiService.sendMessage(conversation: [
            ChatMessage(id: UUID().uuidString, sender: .user, text: initialPrompt, timestamp: Date())
        ])

        viewModel.addAIMessage(aiReply)
        reloadMessages()
    }

    // MARK: - Actions
    @IBAction func sendTapped(_ sender: UIButton) {
        guard let text = messageTextField?.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        messageTextField?.text = ""

        Task { @MainActor in
            await viewModel.sendUserMessage(text)
            reloadMessages()
        }
    }

    // MARK: - Reload UI
    private func reloadMessages() {
        guard let stack = messageStackView else {
            print("❌ messageStackView outlet not connected")
            return
        }

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for message in viewModel.messages {
            let bubbleView = createBubble(for: message)
            stack.addArrangedSubview(bubbleView)
        }

        updateTechnicianButtonState()
    }

    // MARK: - Chat Bubble
    private func createBubble(for message: ChatMessage) -> UIView {
        // ✅ Try to use storyboard templates if available
        if let template = (message.sender == .user ? messageSenderTemplate : messageRecvierrTemplate) {
            let bubble = template.copyViewSafe()

            if let textView = findTextView(in: bubble) {
                if message.sender == .ai, let attributed = try? AttributedString(markdown: message.text) {
                    textView.attributedText = NSAttributedString(attributed)
                } else {
                    textView.text = message.text
                }

                textView.backgroundColor = (message.sender == .user) ? .systemBlue : .systemGray5
                textView.textColor = (message.sender == .user) ? .white : .black
            }

            return bubble
        }

        // ✅ Fallback (NO templates connected): build bubble programmatically
        return buildFallbackBubble(for: message)
    }

    private func buildFallbackBubble(for message: ChatMessage) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.layer.cornerRadius = 12
        textView.clipsToBounds = true

        if message.sender == .ai, let attributed = try? AttributedString(markdown: message.text) {
            textView.attributedText = NSAttributedString(attributed)
        } else {
            textView.text = message.text
        }

        textView.backgroundColor = (message.sender == .user) ? .systemBlue : .systemGray5
        textView.textColor = (message.sender == .user) ? .white : .black

        container.addSubview(textView)

        // Align user right, others left
        let isUser = (message.sender == .user)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),

            isUser
                ? textView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                : textView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])

        // Give some space so it doesn't stretch
        if isUser {
            textView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40).isActive = true
        } else {
            textView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40).isActive = true
        }

        return container
    }

    private func findTextView(in view: UIView) -> UITextView? {
        if let tv = view as? UITextView { return tv }
        for subview in view.subviews {
            if let tv = findTextView(in: subview) { return tv }
        }
        return nil
    }
}


// MARK: - Safe Template Copy
extension UIView {
    func copyViewSafe() -> UIView {
        do {
            let archivedData = try NSKeyedArchiver.archivedData(
                withRootObject: self,
                requiringSecureCoding: false
            )
            
            // Use the modern unarchiving API
            if let copy = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: UIView.self,
                from: archivedData
            ) {
                return copy
            } else {
                return self
            }
        } catch {
            print("❌ Failed to copy view:", error)
            return self
        }
    }
}



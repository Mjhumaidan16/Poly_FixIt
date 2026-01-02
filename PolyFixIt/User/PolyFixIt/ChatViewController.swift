import UIKit
import FirebaseFirestore

final class ChatViewController: UIViewController {

    // MARK: - IBOutlets
    // StackView that holds all chat bubbles (user + AI)
    @IBOutlet weak var messageStackView: UIStackView?

    // Input field where the user types messages
    @IBOutlet weak var messageTextField: UITextField?

    // Send button
    @IBOutlet weak var sendButton: UIButton?

    // Button that becomes enabled once a technician is available
    @IBOutlet weak var changeModeToTechnician: UIButton?

    // Storyboard chat bubble templates (hidden, used only as blueprints)
    @IBOutlet weak var messageSenderTemplate: UIView?
    @IBOutlet weak var messageRecvierrTemplate: UIView?

    // MARK: - Properties

    // ViewModel owns the chat state and AI logic
    private let viewModel = ChatViewModel(mode: .ai)

    // Currently viewed request (hardcoded here for testing)
    var requestId: String = ""

    // Cached Firestore request data
    private var requestData: [String: Any]?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Disable technician button until allowed
        configureInitialState()

        // Prepare storyboard templates so they don’t interfere with layout
        prepareTemplates()

        // Load request data and start AI conversation
        if !requestId.isEmpty {
            fetchRequestData(for: requestId)
        }
    }

    private func configureInitialState() {
        // Technician chat is locked until request is accepted
        changeModeToTechnician?.isEnabled = false
        changeModeToTechnician?.alpha = 0.5
    }

    private func prepareTemplates() {
        // Templates are usually placed inside the stackView in storyboard.
        // We remove them so they don’t appear as actual messages.
        if let stack = messageStackView {

            if let t1 = messageSenderTemplate, stack.arrangedSubviews.contains(t1) {
                stack.removeArrangedSubview(t1)
                t1.removeFromSuperview()
            }

            if let t2 = messageRecvierrTemplate, stack.arrangedSubviews.contains(t2) {
                stack.removeArrangedSubview(t2)
                t2.removeFromSuperview()
            }
        }

        // Templates stay hidden and act only as copy sources
        messageSenderTemplate?.isHidden = true
        messageRecvierrTemplate?.isHidden = true
    }

    private func updateTechnicianButtonState() {
        // Button becomes active only when ViewModel allows it
        let enabled = viewModel.canSwitchToTechnicianChat()
        changeModeToTechnician?.isEnabled = enabled
        changeModeToTechnician?.alpha = enabled ? 1.0 : 0.5
    }

    // MARK: - Firestore
    private func fetchRequestData(for requestId: String) {
        let db = Firestore.firestore()
        let docRef = db.collection("requests").document(requestId)

        // Fetch request details (title, description, image, etc.)
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

            // Once data is ready, start the AI conversation
            Task { @MainActor in
                await self.sendInitialAIMessage()
            }
        }
    }

    // MARK: - Initial AI Prompt
    @MainActor
    private func sendInitialAIMessage() async {
        guard let data = requestData else { return }

        // Extract fields safely
        let title = data["title"] as? String ?? "No title"
        let description = data["description"] as? String ?? "No description"
        let category = data["selectedCategory"] as? String ?? "General"
        let imageUrl = data["imageUrl"] as? String ?? ""

        // This prompt “sets the context” for the AI
        let initialPrompt = """
        Request Data:
        - Title: \(title)
        - Description: \(description)
        - Category: \(category)
        - Image: \(imageUrl)

        Start the conversation following PolyFixIt AI workflow.
        """

        // Send context to AI and wait for reply
        let aiReply = await viewModel.aiService.sendMessage(conversation: [
            ChatMessage(id: UUID().uuidString, sender: .user, text: initialPrompt, timestamp: Date())
        ])

        // Add AI reply as a new message
        viewModel.addAIMessage(aiReply)
        reloadMessages()
    }

    // MARK: - Actions
    @IBAction func sendTapped(_ sender: UIButton) {

        // Validate user input
        guard let text = messageTextField?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Clear input immediately so UI feels responsive
        messageTextField?.text = ""

        Task { @MainActor in
            // Add user message first (instant UI feedback)
            await viewModel.sendUserMessage(text)

            // Then rebuild UI
            reloadMessages()
        }
    }

    // MARK: - Reload UI
    private func reloadMessages() {
        guard let stack = messageStackView else {
            print("❌ messageStackView outlet not connected")
            return
        }

        // Clear old bubbles
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        // Recreate bubbles from ViewModel state (source of truth)
        for message in viewModel.messages {
            let bubbleView = createBubble(for: message)
            stack.addArrangedSubview(bubbleView)
        }

        updateTechnicianButtonState()
    }

    // MARK: - Chat Bubble Creation
    private func createBubble(for message: ChatMessage) -> UIView {

        // Try storyboard template first (cleaner UI, consistent layout)
        if let template = (message.sender == .user ? messageSenderTemplate : messageRecvierrTemplate),
           let bubble = template.deepCopyView() {

            // Find the UITextView inside the copied template
            if let textView = findTextView(in: bubble) {

                // AI supports markdown formatting
                if message.sender == .ai,
                   let attributed = try? AttributedString(markdown: message.text) {
                    textView.attributedText = NSAttributedString(attributed)
                } else {
                    textView.text = message.text
                }

                // Style based on sender
                textView.backgroundColor = (message.sender == .user) ? .systemBlue : .systemGray5
                textView.textColor = (message.sender == .user) ? .white : .black
            }

            return bubble
        }

        // If template copy fails, fall back to code-built bubble
        return buildFallbackBubble(for: message)
    }

    // MARK: - Programmatic Bubble (Fallback)
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

        // Apply markdown only for AI
        if message.sender == .ai,
           let attributed = try? AttributedString(markdown: message.text) {
            textView.attributedText = NSAttributedString(attributed)
        } else {
            textView.text = message.text
        }

        textView.backgroundColor = (message.sender == .user) ? .systemBlue : .systemGray5
        textView.textColor = (message.sender == .user) ? .white : .black

        container.addSubview(textView)

        let isUser = (message.sender == .user)

        // Align bubbles left or right
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            isUser
                ? textView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                : textView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])

        // Prevent full-width stretching
        if isUser {
            textView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40).isActive = true
        } else {
            textView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40).isActive = true
        }

        return container
    }

    // Recursively search for UITextView inside template
    private func findTextView(in view: UIView) -> UITextView? {
        if let tv = view as? UITextView { return tv }
        for subview in view.subviews {
            if let tv = findTextView(in: subview) { return tv }
        }
        return nil
    }
}

// MARK: - Template Deep Copy (CRITICAL FIX)
// MARK: - Template Deep Copy (FIXED)
extension UIView {

    /// Creates a brand-new UIView instance by archiving/unarchiving the view tree.
    /// Uses NON-secure coding because UIView is NOT NSSecureCoding.
    func deepCopyView() -> UIView? {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: self,
                requiringSecureCoding: false
            )

            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }

            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? UIView
        } catch {
            print("❌ Failed to deep copy view:", error)
            return nil
        }
    }
}


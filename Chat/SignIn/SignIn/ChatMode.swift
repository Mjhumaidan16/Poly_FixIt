import Foundation

enum ChatMode { case ai, technicianChat }
enum SenderType { case user, ai, technician, admin, system }

struct ChatMessage {
    let id: String
    let sender: SenderType
    let text: String
    let timestamp: Date
}

@MainActor
final class ChatViewModel {

    private(set) var messages: [ChatMessage] = []
    let aiService = AIChatService()
    private(set) var chatMode: ChatMode

    var requestAccepted: Bool = false
    var assignedTechnicianID: String?

    var onMessagesUpdated: (() -> Void)?

    init(mode: ChatMode) { self.chatMode = mode }

    func canSwitchToTechnicianChat() -> Bool {
        requestAccepted && assignedTechnicianID != nil
    }

    func switchToTechnicianChat() {
        guard canSwitchToTechnicianChat() else { return }
        chatMode = .technicianChat
        addSystemMessage("You are now connected to a technician.")
    }

    @MainActor
    func sendUserMessage(_ text: String) async {
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            sender: .user,
            text: text,
            timestamp: Date()
        )
        messages.append(userMessage)
        onMessagesUpdated?() // refresh UI

        guard chatMode == .ai else { return }

        let reply = await aiService.sendMessage(conversation: messages)
        addAIMessage(reply)
        onMessagesUpdated?()
    }


    func addAIMessage(_ text: String) {
        messages.append(
            ChatMessage(id: UUID().uuidString, sender: .ai, text: text, timestamp: Date())
        )
    }

    func addSystemMessage(_ text: String) {
        messages.append(
            ChatMessage(id: UUID().uuidString, sender: .system, text: text, timestamp: Date())
        )
    }
}

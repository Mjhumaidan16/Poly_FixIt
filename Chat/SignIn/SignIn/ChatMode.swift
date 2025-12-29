//
//  ChatMode.swift
//  SignIn
//
//  Created by BP-19-131-12 on 29/12/2025.
//


import Foundation

// MARK: - Chat Mode
enum ChatMode {
    case ai
    case technicianChat
}

// MARK: - Sender Type
enum SenderType {
    case user
    case ai
    case technician
    case admin
    case system
}

// MARK: - Chat Message Model
struct ChatMessage {
    let id: String
    let sender: SenderType
    let text: String
    let timestamp: Date
}

// MARK: - Chat ViewModel (Thesis Core Logic)

final class ChatViewModel {

    private(set) var messages: [ChatMessage] = []
    private let aiService = AIChatService()

    private(set) var chatMode: ChatMode

    // 🔐 Request State
    var requestAccepted: Bool = false
    var assignedTechnicianID: String?

    init(mode: ChatMode) {
        self.chatMode = mode
    }

    // MARK: - Mode Control

    func canSwitchToTechnicianChat() -> Bool {
        requestAccepted && assignedTechnicianID != nil
    }

    func switchToTechnicianChat() {
        guard canSwitchToTechnicianChat() else { return }

        chatMode = .technicianChat

        messages.append(
            ChatMessage(
                id: UUID().uuidString,
                sender: .system,
                text: "You are now connected to a technician.",
                timestamp: Date()
            )
        )
    }

    // MARK: - Messaging

    func sendUserMessage(
        _ text: String,
        completion: @escaping () -> Void
    ) {

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            sender: .user,
            text: text,
            timestamp: Date()
        )

        messages.append(userMessage)
        completion()

        guard chatMode == .ai else {
            // 🔧 Technician chat (Firebase/WebSocket later)
            return
        }

        Task {
            do {
                let reply = try await aiService.sendMessage(conversation: messages)

                let aiMessage = ChatMessage(
                    id: UUID().uuidString,
                    sender: .ai,
                    text: reply,
                    timestamp: Date()
                )

                DispatchQueue.main.async {
                    self.messages.append(aiMessage)
                    completion()
                }

            } catch {
                print("AI Error:", error)
            }
        }
    }
}

//
//  AIChatService.swift
//  SignIn
//
//  Created by BP-19-131-12 on 29/12/2025.
//

import Foundation
import OpenAI

final class AIChatService {

    private let client: OpenAIProtocol

    init() {
        // ⚠️ FOR THESIS / DEMO ONLY
        // In production → proxy through backend
        let config = OpenAI.Configuration(
            token: "YOUR_API_KEY",
            timeoutInterval: 60
        )
        self.client = OpenAI(configuration: config)
    }

    func sendMessage(
        conversation: [ChatMessage]
    ) async throws -> String {

        let chatMessages: [ChatQuery.Message] = conversation.compactMap { message in
            switch message.sender {
            case .user:
                return .user(.init(content: .string(message.text)))
            case .ai:
                return .assistant(.init(content: .string(message.text)))
            case .system:
                return .system(.init(content: .string(message.text)))
            default:
                return nil // technician/admin not sent to AI
            }
        }

        let query = ChatQuery(
            messages: chatMessages,
            model: .gpt4_o_mini
        )

        let result = try await client.chats(query: query)

        return result.choices.first?.message.content ?? "No response"
    }
}

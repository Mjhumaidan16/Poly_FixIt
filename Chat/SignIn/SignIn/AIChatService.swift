import Foundation

final class AIChatService {

    // MARK: - API Key
    private let apiKey: String = {
        guard let key = Bundle.main.object(
            forInfoDictionaryKey: "GEMINI_API_KEY"
        ) as? String else {
            fatalError("❌ GEMINI_API_KEY missing in Info.plist")
        }
        return key
    }()

    // MARK: - Endpoint
    private let endpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"

    // MARK: - Send Message
    func sendMessage(conversation: [ChatMessage]) async -> String {
        print("📤 Sending message to Gemini...")
        print("🧠 Conversation count:", conversation.count)
        print("🗨️ Conversation texts:", conversation.map{$0.text})

        let contents: [[String: Any]] = conversation.map {
            [
                "role": $0.sender == .user ? "user" : "model",
                "parts": [["text": $0.text]]
            ]
        }

        let body: [String: Any] = ["contents": contents]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            print("❌ Invalid URL")
            return "⚠️ Invalid URL"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Failed to encode request body:", error)
            return "⚠️ Failed to encode request"
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("📥 HTTP Status Code:", http.statusCode)
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            print("📥 Raw Response:", raw)

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard
                let candidates = json?["candidates"] as? [[String: Any]],
                let firstCandidate = candidates.first,
                let content = firstCandidate["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let firstPart = parts.first,
                let reply = firstPart["text"] as? String
            else {
                print("⚠️ Failed to parse response")
                return "⚠️ AI returned no response"
            }

            print("✅ AI Reply:", reply)
            return reply

        } catch {
            print("❌ Network / JSON error:", error)
            return "⚠️ AI service error"
        }
    }
}

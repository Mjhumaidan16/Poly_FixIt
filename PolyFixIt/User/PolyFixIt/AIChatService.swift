
import Foundation

final class AIChatService {
    
    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String else {
            fatalError("❌ GEMINI_API_KEY missing in Info.plist")
        }
        return key
    }()
    
    private let endpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    
    func sendMessage(conversation: [ChatMessage]) async -> String {
        
        // 1) Convert ChatMessage[] -> Gemini "contents" while ensuring role alternation.
        // Gemini expects the role to alternate user/model/user/model... :contentReference[oaicite:2]{index=2}
        var contents: [[String: Any]] = []
        
        func roleFor(_ sender: SenderType) -> String {
            switch sender {
            case .user:
                return "user"
            case .ai:
                return "model"
            case .system, .technician, .admin:
                // IMPORTANT:
                // Treat these as "user" so we don't accidentally create model/model sequences.
                return "user"
            }
        }
        
        // Merge consecutive messages of the same role into one Content.
        // This keeps the conversation valid even if your app generates system notices, etc.
        var lastRole: String? = nil
        var bufferText: String = ""
        
        func flushBuffer() {
            guard let lastRole, !bufferText.isEmpty else { return }
            contents.append([
                "role": lastRole,
                "parts": [["text": bufferText]]
            ])
            bufferText = ""
        }
        
        for msg in conversation {
            let role = roleFor(msg.sender)
            
            // Optional: label non-user messages that we converted into "user"
            let text: String
            switch msg.sender {
            case .system:     text = "SYSTEM: \(msg.text)"
            case .technician: text = "TECHNICIAN: \(msg.text)"
            case .admin:      text = "ADMIN: \(msg.text)"
            default:          text = msg.text
            }
            
            if lastRole == nil {
                lastRole = role
                bufferText = text
            } else if role == lastRole {
                // same role -> merge
                bufferText += "\n" + text
            } else {
                // role changed -> flush previous
                flushBuffer()
                lastRole = role
                bufferText = text
            }
        }
        flushBuffer()
        
        // Gemini also generally expects the last turn to be user.
        // If your history ends with model, add a tiny user nudge.
        if let last = contents.last?["role"] as? String, last == "model" {
            contents.append([
                "role": "user",
                "parts": [["text": "Continue."]]
            ])
        }
        
        let body: [String: Any] = ["contents": contents]
        
        guard let url = URL(string: endpoint) else {
            return "⚠️ Invalid URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Recommended way: pass API key in header (still works with query param sometimes,
        // but this is the documented approach). :contentReference[oaicite:3]{index=3}
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return "⚠️ Failed to encode request"
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Helpful during debugging
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let raw = String(data: data, encoding: .utf8) ?? ""
                return "⚠️ HTTP \(http.statusCode): \(raw)"
            }
            
            let json = (try JSONSerialization.jsonObject(with: data)) as? [String: Any]
            
            // 2) If Google returns an error object, show it.
            if let errorObj = json?["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                return "⚠️ Gemini error: \(message)"
            }
            
            // 3) Normal path: candidates -> content -> parts -> text
            if
                let candidates = json?["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            {
                // Join all text parts (sometimes there are multiple)
                let texts = parts.compactMap { $0["text"] as? String }
                let reply = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty { return reply }
            }
            
            // 4) If no candidates, often the reason is in promptFeedback.blockReason :contentReference[oaicite:4]{index=4}
            if let promptFeedback = json?["promptFeedback"] as? [String: Any],
               let blockReason = promptFeedback["blockReason"] as? String {
                return "⚠️ Gemini blocked the prompt: \(blockReason)"
            }
            
            // Last resort: show raw so you can see what changed
            let raw = String(data: data, encoding: .utf8) ?? ""
            return "⚠️ AI returned no response. Raw: \(raw)"
            
        } catch {
            return "⚠️ AI service error: \(error.localizedDescription)"
        }
    }
}

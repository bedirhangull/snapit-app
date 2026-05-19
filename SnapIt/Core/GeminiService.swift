//
//  GeminiService.swift
//  Snap It
//

import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case badHTTP(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing GEMINI_API_KEY environment variable."
        case .badHTTP(let code, let body):
            return "Gemini HTTP \(code): \(body.prefix(600))"
        case .decoding:
            return "Could not parse Gemini response."
        }
    }
}

final class GeminiService: @unchecked Sendable {
    static let shared = GeminiService()

    private let rootURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private let defaultModel = "gemini-2.5-flash"
    private let imageModel = "gemini-2.5-flash-image"

    private init() {}

    private func apiKey() throws -> String {
        let key = GeminiConfig.apiKey
        guard !key.isEmpty else { throw GeminiError.missingAPIKey }
        return key
    }

    private func postJSON(url: URL, body: Any) async throws -> [String: Any] {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "key", value: try apiKey())]
        guard let finalURL = comps.url else { throw GeminiError.decoding }

        var req = URLRequest(url: finalURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GeminiError.decoding }

        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.badHTTP(http.statusCode, bodyText)
        }

        return obj ?? [:]
    }

    struct ShoppingPlan: Sendable {
        struct Complementary: Sendable {
            let label: String
            let query: String
        }
        let summary: String
        let primaryLabel: String
        let primaryQuery: String
        let complementary: [Complementary]
    }

    func extractShoppingPlan(screenJPEG: Data) async throws -> ShoppingPlan {
        let model = defaultModel

        let parts: [[String: Any]] = [
            [
                "text": """
You are a sharp shopping assistant. Look at this macOS screen capture (often an e‑commerce product page).
Identify the primary apparel piece the user is likely shopping (shirt/jacket/pants/dress/shoes/etc).

Return STRICT JSON only (no prose) with this shape:
{
  "summary": "2-4 short sentences in friendly tone describing the item (color, material, fit, vibe).",
  "primary_label": "Short noun like \\"Jacket\\" or \\"Sneakers\\".",
  "primary_query": "Concrete shopping query for Google Shopping in English (5-10 words, include color + material + gender if visible).",
  "complementary": [
    { "label": "Pants", "query": "..." },
    { "label": "Shoes", "query": "..." },
    { "label": "Accessory", "query": "..." }
  ]
}

Rules:
- complementary must have exactly 3 items, each a different category that pairs well with the primary item.
- queries must be plain English shopping search strings; no quotes inside, no brand names unless visible in the image.
- if no apparel is visible, set summary to a brief honest note and return empty complementary array.
"""
            ],
            [
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": screenJPEG.base64EncodedString()
                ]
            ]
        ]

        let contents: [[String: Any]] = [
            ["role": "user", "parts": parts]
        ]

        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: body)
        let raw = try Self.extractText(from: json)
        return try Self.decodeShoppingPlan(rawJSON: raw)
    }

    func extractShoppingPlanFromText(_ text: String) async throws -> ShoppingPlan {
        let model = defaultModel
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiError.decoding }

        let parts: [[String: Any]] = [
            [
                "text": """
You are a sharp shopping assistant. The user just typed this shopping intent:
\"\(trimmed)\"

Identify what they likely want to buy (apparel, footwear, gear, accessories) and return STRICT JSON only (no prose) with this shape:
{
  "summary": "1-3 short friendly sentences confirming what you'll search for.",
  "primary_label": "Short noun like \\"Running shoes\\" or \\"Winter coat\\".",
  "primary_query": "Concrete Google Shopping query in English (5-10 words; add gender if implied).",
  "complementary": [
    { "label": "Shorts", "query": "..." },
    { "label": "Top",    "query": "..." },
    { "label": "Socks",  "query": "..." }
  ]
}

Rules:
- complementary must have exactly 3 items, each a category that pairs well with the primary item.
- queries are plain English shopping search strings; no quotes, no brand names unless the user mentioned one.
- if intent is unclear (e.g. "merhaba", "help me"), return summary = short clarification ask, primary_query = "", complementary = [].
"""
            ]
        ]

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: body)
        let raw = try Self.extractText(from: json)
        return try Self.decodeShoppingPlan(rawJSON: raw)
    }

    private static func decodeShoppingPlan(rawJSON: String) throws -> ShoppingPlan {
        guard let data = rawJSON.data(using: .utf8),
              let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw GeminiError.decoding
        }

        let summary = (parsed["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let primaryLabel = (parsed["primary_label"] as? String) ?? "Item"
        let primaryQuery = (parsed["primary_query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let compRaw = parsed["complementary"] as? [[String: Any]] ?? []
        let complementary: [ShoppingPlan.Complementary] = compRaw.compactMap { item in
            guard let label = item["label"] as? String,
                  let query = item["query"] as? String,
                  !label.isEmpty, !query.isEmpty else { return nil }
            return ShoppingPlan.Complementary(label: label, query: query)
        }

        guard !summary.isEmpty else { throw GeminiError.decoding }

        return ShoppingPlan(
            summary: summary,
            primaryLabel: primaryLabel,
            primaryQuery: primaryQuery,
            complementary: complementary
        )
    }

    func describeVisibleOutfit(screenJPEG: Data) async throws -> String {
        let model = defaultModel

        let parts: [[String: Any]] = [
            [
                "text": """
You are a sharp shopping assistant. Look at this macOS screen capture (often an e‑commerce product page).
Identify the primary apparel piece the user is likely shopping (shirt/jacket/pants/dress/etc).

Reply with:
- **Item**: short title
- **Details**: colors/pattern/material/fit cues you can see
- **Styling**: vibe / occasions
- **Questions**: one clarifying question if something critical is unclear

Keep it concise and actionable.
"""
            ],
            [
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": screenJPEG.base64EncodedString()
                ]
            ]
        ]

        let contents: [[String: Any]] = [
            ["role": "user", "parts": parts]
        ]

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: ["contents": contents])
        return try Self.extractText(from: json)
    }

    struct ChatIntentResult: Sendable {
        let reply: String
        let newPlan: ShoppingPlan?
    }

    func chatWithIntent(
        history: [[String: Any]],
        newUserText: String,
        screenJPEG: Data?
    ) async throws -> ChatIntentResult {
        let model = defaultModel
        var contents = history

        var parts: [[String: Any]] = [[
            "text": """
You are SnapIt's shopping assistant. The user is in a chat with you. They may either (a) be asking a follow-up about the current items / screenshot, or (b) pivoting to a NEW shopping intent (e.g. "I also want to play basketball — I need a basketball", "show me jackets", "what about hiking shoes?").

Latest user message:
\"\(newUserText)\"

Return STRICT JSON only (no prose). Schema:
{
  "reply": "Friendly 1-3 sentence reply to acknowledge the user, in the user's language.",
  "new_search": null OR {
    "summary": "1-3 sentence summary of what you'll search for.",
    "primary_label": "Short noun (e.g. \\"Basketball\\", \\"Hiking boots\\").",
    "primary_query": "Concrete Google Shopping query in English (5-10 words, include gender if implied).",
    "complementary": [
      { "label": "...", "query": "..." },
      { "label": "...", "query": "..." },
      { "label": "...", "query": "..." }
    ]
  }
}

Rules:
- If the user is asking for a NEW PRODUCT CATEGORY (different sport, different garment type, accessory they didn't mention before) → populate new_search with a fresh ShoppingPlan (exactly 3 complementary items).
- If the user is just asking a question about the current items (sizing, styling, comparison, alternatives within the same category) → set new_search to null and answer in "reply".
- "reply" is always required and short. Speak the user's language if obvious; otherwise English.
- complementary items must be 3 distinct categories that pair with the primary intent.
- queries must be plain English Google Shopping search strings.
"""
        ]]

        if let screenJPEG {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": screenJPEG.base64EncodedString()
                ]
            ])
        }

        contents.append(["role": "user", "parts": parts])

        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: body)
        let raw = try Self.extractText(from: json)

        guard let data = raw.data(using: .utf8),
              let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw GeminiError.decoding
        }

        let reply = (parsed["reply"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !reply.isEmpty else { throw GeminiError.decoding }

        var newPlan: ShoppingPlan? = nil
        if let planDict = parsed["new_search"] as? [String: Any] {
            if let planJSONData = try? JSONSerialization.data(withJSONObject: planDict),
               let planJSON = String(data: planJSONData, encoding: .utf8),
               let decoded = try? Self.decodeShoppingPlan(rawJSON: planJSON) {
                newPlan = decoded
            }
        }

        return ChatIntentResult(reply: reply, newPlan: newPlan)
    }

    func chatReply(history: [[String: Any]], newUserText: String, screenJPEG: Data?) async throws -> String {
        let model = defaultModel

        var contents = history

        var parts: [[String: Any]] = [["text": newUserText]]

        if let screenJPEG {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": screenJPEG.base64EncodedString()
                ]
            ])
        }

        contents.append(["role": "user", "parts": parts])

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: ["contents": contents])
        return try Self.extractText(from: json)
    }

    func generateComboImage(thumbnails: [Data], productTitles: [String]) async throws -> Data {
        guard !thumbnails.isEmpty else { throw GeminiError.decoding }

        let titleList = productTitles
            .enumerated()
            .map { "  \($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let promptText = """
Compose ONE clean studio image of a 3D CGI grey clay mannequin wearing the outfit assembled from the reference images attached.

Items to dress the mannequin in:
\(titleList)

Strict requirements:
- The figure is a 3D CGI mannequin with a MATTE MONOCHROME GREY / CLAY surface — no facial features, no skin texture, no hair, no eyes (think a Clip Studio Assets 3D body reference or a blank fashion store mannequin)
- The mannequin's body must remain fully grey/clay throughout — do NOT render skin, hair, or human features
- Only the CLOTHING and ACCESSORIES should be rendered in full color, material, and detail, faithful to the reference images (correct color, pattern, fit, length)
- Clean seamless WHITE photography studio backdrop, soft even key+fill lighting, subtle ground shadow only
- Single mannequin, centered, standing straight and front-facing, full body shot
- Editorial fashion lookbook framing, sharp focus on the garments
- No text, no logos, no watermarks, no extra props, no background objects
- Output: a single image, no commentary
"""

        var parts: [[String: Any]] = [["text": promptText]]
        for data in thumbnails {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": data.base64EncodedString()
                ]
            ])
        }

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseModalities": ["IMAGE"]
            ]
        ]

        let url = rootURL.appendingPathComponent("models/\(imageModel):generateContent")
        let json = try await postJSON(url: url, body: body)
        return try Self.extractInlineImage(from: json)
    }

    func contentsPayload(from turns: [ChatTurn]) -> [[String: Any]] {
        turns.map { turn in
            [
                "role": turn.role == .user ? "user" : "model",
                "parts": [["text": turn.text]]
            ]
        }
    }

    private static func extractInlineImage(from json: [String: Any]) throws -> Data {
        if let error = json["error"] as? [String: Any],
           let msg = error["message"] as? String {
            throw GeminiError.badHTTP(400, msg)
        }

        if let promptFeedback = json["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            throw GeminiError.badHTTP(400, "Blocked: \(blockReason)")
        }

        guard let candidates = json["candidates"] as? [[String: Any]], !candidates.isEmpty else {
            let snippet = String(describing: json).prefix(900)
            throw GeminiError.badHTTP(422, "No image candidates returned. Raw (truncated): \(snippet)")
        }

        guard let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.decoding
        }

        for part in parts {
            // Gemini may return either snake_case `inline_data` or camelCase `inlineData`.
            if let inline = (part["inline_data"] as? [String: Any]) ?? (part["inlineData"] as? [String: Any]),
               let base64 = inline["data"] as? String,
               let data = Data(base64Encoded: base64) {
                return data
            }
        }

        throw GeminiError.decoding
    }

    private static func extractText(from json: [String: Any]) throws -> String {
        if let error = json["error"] as? [String: Any],
           let msg = error["message"] as? String {
            throw GeminiError.badHTTP(400, msg)
        }

        if let promptFeedback = json["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            throw GeminiError.badHTTP(400, "Blocked: \(blockReason)")
        }

        guard let candidates = json["candidates"] as? [[String: Any]], !candidates.isEmpty else {
            let snippet = String(describing: json).prefix(900)
            throw GeminiError.badHTTP(
                422,
                "No candidates returned from Gemini (often safety/settings). Raw (truncated): \(snippet)"
            )
        }

        guard let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.decoding
        }

        let texts = parts.compactMap { $0["text"] as? String }
        let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw GeminiError.decoding }
        return joined
    }
}

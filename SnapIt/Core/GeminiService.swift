//
//  GeminiService.swift
//  Snap It
//

import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case badHTTP(Int, String)
    case decoding
    case videoUnsupported(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing GEMINI_API_KEY environment variable."
        case .badHTTP(let code, let body):
            return "Gemini HTTP \(code): \(body.prefix(600))"
        case .decoding:
            return "Could not parse Gemini response."
        case .videoUnsupported(let detail):
            return detail
        }
    }
}

final class GeminiService: @unchecked Sendable {
    static let shared = GeminiService()

    private let rootURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

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

    private func getJSON(url: URL) async throws -> [String: Any] {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "key", value: try apiKey())]
        guard let finalURL = comps.url else { throw GeminiError.decoding }

        var req = URLRequest(url: finalURL)
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GeminiError.decoding }

        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.badHTTP(http.statusCode, bodyText)
        }

        return obj ?? [:]
    }

    func describeVisibleOutfit(screenJPEG: Data, bodyJPEG: Data?) async throws -> String {
        let model = "gemini-2.0-flash"

        var parts: [[String: Any]] = [
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

        if let bodyJPEG {
            parts.append([
                "text": "Optional: this is the shopper’s reference body photo for future try‑on context."
            ])
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": bodyJPEG.base64EncodedString()
                ]
            ])
        }

        let contents: [[String: Any]] = [
            ["role": "user", "parts": parts]
        ]

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: ["contents": contents])
        return try Self.extractText(from: json)
    }

    func chatReply(history: [[String: Any]], newUserText: String, screenJPEG: Data?, bodyJPEG: Data?) async throws -> String {
        let model = "gemini-2.0-flash"

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

        if let bodyJPEG {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": bodyJPEG.base64EncodedString()
                ]
            ])
        }

        contents.append(["role": "user", "parts": parts])

        let url = rootURL.appendingPathComponent("models/\(model):generateContent")
        let json = try await postJSON(url: url, body: ["contents": contents])
        return try Self.extractText(from: json)
    }

    func contentsPayload(from turns: [ChatTurn]) -> [[String: Any]] {
        turns.map { turn in
            [
                "role": turn.role == .user ? "user" : "model",
                "parts": [["text": turn.text]]
            ]
        }
    }

    func generateTryOnVideo(prompt: String, screenJPEG: Data, bodyJPEG: Data) async throws -> URL {
        let models = ["veo-3.1-generate-preview", "veo-2.0-generate-001"]

        var lastError: Error = GeminiError.videoUnsupported("Video generation failed for all models.")

        for model in models {
            do {
                return try await startVeoOperation(model: model, prompt: prompt, screenJPEG: screenJPEG, bodyJPEG: bodyJPEG)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func startVeoOperation(model: String, prompt: String, screenJPEG: Data, bodyJPEG: Data) async throws -> URL {
        let url = rootURL.appendingPathComponent("models/\(model):predictLongRunning")

        let instance: [String: Any] = [
            "prompt": prompt,
            "referenceImages": [
                [
                    "referenceType": "REFERENCE_TYPE_ASSET",
                    "referenceImage": [
                        "bytesBase64Encoded": screenJPEG.base64EncodedString(),
                        "mimeType": "image/jpeg"
                    ]
                ],
                [
                    "referenceType": "REFERENCE_TYPE_SUBJECT",
                    "referenceImage": [
                        "bytesBase64Encoded": bodyJPEG.base64EncodedString(),
                        "mimeType": "image/jpeg"
                    ]
                ]
            ]
        ]

        let body: [String: Any] = [
            "instances": [instance],
            "parameters": [
                "aspectRatio": "9:16",
                "durationSeconds": 6,
                "sampleCount": 1
            ] as [String: Any]
        ]

        let json = try await postJSON(url: url, body: body)

        guard let opName = json["name"] as? String else {
            throw GeminiError.videoUnsupported("Missing long-running operation name from Veo.")
        }

        let videoURI = try await pollOperation(name: opName)
        return try await downloadVideo(from: videoURI)
    }

    private func pollOperation(name: String) async throws -> String {
        guard let opURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(name)") else {
            throw GeminiError.decoding
        }

        for _ in 0 ..< 90 {
            let json = try await getJSON(url: opURL)

            if let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                throw GeminiError.videoUnsupported(msg)
            }

            if let done = json["done"] as? Bool, done {
                if let response = json["response"] as? [String: Any],
                   let uri = Self.findVideoURI(in: response) {
                    return uri
                }

                let debug = String(describing: json)
                throw GeminiError.videoUnsupported(
                    "Video finished but no downloadable URI was found. Raw (truncated): \(debug.prefix(900))"
                )
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        throw GeminiError.videoUnsupported("Video generation timed out.")
    }

    private func downloadVideo(from uri: String) async throws -> URL {
        guard uri.hasPrefix("http"), var components = URLComponents(string: uri) else {
            throw GeminiError.videoUnsupported("Unsupported video URI: \(uri.prefix(240))")
        }

        let existing = components.queryItems ?? []
        components.queryItems = existing + [URLQueryItem(name: "key", value: try apiKey())]

        guard let authed = components.url else { throw GeminiError.decoding }

        let (tmpURL, resp) = try await URLSession.shared.download(from: authed)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw GeminiError.videoUnsupported("Download failed.")
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapit-tryon-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpURL, to: dest)
        return dest
    }

    private static func extractText(from json: [String: Any]) throws -> String {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.decoding
        }

        let texts = parts.compactMap { $0["text"] as? String }
        let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw GeminiError.decoding }
        return joined
    }

    private static func findVideoURI(in dict: [String: Any]) -> String? {
        if let uri = dict["uri"] as? String, uri.hasPrefix("http") { return uri }

        for (_, value) in dict {
            if let s = value as? String, s.hasPrefix("http") {
                return s
            }
            if let child = value as? [String: Any], let found = findVideoURI(in: child) {
                return found
            }
            if let arr = value as? [[String: Any]] {
                for child in arr {
                    if let found = findVideoURI(in: child) { return found }
                }
            }
        }

        return nil
    }
}

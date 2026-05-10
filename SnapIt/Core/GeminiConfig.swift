//
//  GeminiConfig.swift
//  Snap It
//

import Foundation

enum GeminiConfig {
    /// Prefer `GEMINI_API_KEY` from the Xcode scheme environment (see README).
    static var apiKey: String {
        let trimmed = (ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}

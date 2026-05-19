//
//  GeminiConfig.swift
//  Snap It
//

import Foundation

enum GeminiConfig {
    /// Looks up the Gemini API key. Order:
    /// 1. `GEMINI_API_KEY` environment variable (Xcode scheme — works when running from Xcode)
    /// 2. `GEMINI_API_KEY` from Info.plist (baked into the bundle — works after "Quit & Reopen"
    ///    when the OS relaunches the app outside Xcode and scheme env vars are gone).
    static var apiKey: String {
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String {
            return plist.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}

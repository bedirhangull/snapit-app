//
//  SerpAPIConfig.swift
//  Snap It
//

import Foundation

enum SerpAPIConfig {
    /// Looks up the SerpAPI key. Order:
    /// 1. `SERPAPI_API_KEY` environment variable (Xcode scheme).
    /// 2. `SERPAPI_API_KEY` from Info.plist (baked into the bundle for standalone launches).
    static var apiKey: String {
        if let env = ProcessInfo.processInfo.environment["SERPAPI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "SERPAPI_API_KEY") as? String {
            return plist.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}

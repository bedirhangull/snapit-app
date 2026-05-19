//
//  ShortcutFeedback.swift
//  Snap It
//

import AudioToolbox
import Foundation

enum ShortcutFeedback {
    /// Light UI tick when the island opens via ⌃⇧S (system sound — no bundled asset).
    static func playIslandOpen() {
        AudioServicesPlaySystemSound(1104)
    }

    /// Softer cue when the island closes via ⌃⇧S.
    static func playIslandClose() {
        AudioServicesPlaySystemSound(1055)
    }
}

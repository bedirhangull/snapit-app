//
//  GlobalShortcutManager.swift
//  Snap It
//
//  Control + Shift + S toggles the island from any app (requires Accessibility permission).
//

import AppKit
import Foundation

@MainActor
final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private weak var viewModel: NotchViewModel?

    private init() {}

    func register(viewModel: NotchViewModel) {
        self.viewModel = viewModel

        unregister()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
            return event
        }
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasControl = flags.contains(.control)
        let hasShift = flags.contains(.shift)
        guard hasControl, hasShift else { return }

        // ANSI "S"
        guard event.keyCode == 1 else { return }

        toggleIsland()
    }

    private func toggleIsland() {
        guard let viewModel else { return }
        if viewModel.status == .opened {
            ShortcutFeedback.playIslandClose()
            viewModel.notchClose()
        } else {
            ShortcutFeedback.playIslandOpen()
            viewModel.notchOpen(reason: .shortcut)
        }
    }
}

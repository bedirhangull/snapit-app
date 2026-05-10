//
//  AppDelegate.swift
//  Snap It
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var windowManager: WindowManager?
    private var screenObserver: ScreenObserver?
    private var statusItem: NSStatusItem?

    var windowController: NotchWindowController? {
        windowManager?.windowController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApplication.shared.setActivationPolicy(.accessory)

        windowManager = WindowManager()
        _ = windowManager?.setupNotchWindow()

        screenObserver = ScreenObserver { [weak self] in
            _ = self?.windowManager?.setupNotchWindow()
        }

        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "Snap It"
            button.toolTip = "Snap It — Control⇧S"
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Island", action: #selector(openIsland), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Snap It", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openIsland() {
        windowController?.viewModel.notchOpen(reason: .passive)
        NSApp.activate(ignoringOtherApps: true)
    }
}

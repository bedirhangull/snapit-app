//
//  WindowManager.swift
//  Snap It
//

import AppKit
import os.log

private let logger = Logger(subsystem: "app.snapit.mac", category: "Window")

final class WindowManager {
    private(set) var windowController: NotchWindowController?

    func setupNotchWindow() -> NotchWindowController? {
        let screenSelector = ScreenSelector.shared
        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            logger.warning("No screen found")
            return nil
        }

        if let existingController = windowController {
            existingController.window?.orderOut(nil)
            existingController.window?.close()
            windowController = nil
        }

        windowController = NotchWindowController(screen: screen)
        windowController?.showWindow(nil)

        return windowController
    }
}

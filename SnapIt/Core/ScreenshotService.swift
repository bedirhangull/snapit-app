//
//  ScreenshotService.swift
//  Snap It
//

import AppKit
import CoreGraphics

enum ScreenshotService {
    /// Captures the given display using `CGDisplayCreateImage` (requires Screen Recording permission).
    static func capture(screen: NSScreen) -> NSImage? {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }

        guard let cgImage = CGDisplayCreateImage(num) else {
            return nil
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
}

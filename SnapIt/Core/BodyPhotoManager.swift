//
//  BodyPhotoManager.swift
//  Snap It
//

import AppKit
import UniformTypeIdentifiers

@MainActor
final class BodyPhotoManager: ObservableObject {
    static let shared = BodyPhotoManager()

    @Published private(set) var image: NSImage?

    private let defaultsKey = "snapit.bodyPhotoJPEG"

    private init() {
        reloadFromDefaults()
    }

    func reloadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            image = nil
            return
        }
        image = NSImage(data: data)
    }

    func save(_ image: NSImage) {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        self.image = image
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        image = nil
    }

    func pickFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.jpeg, .png, .heic]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let img = NSImage(contentsOf: url) else { return }
            Task { @MainActor in
                self.save(img)
            }
        }
    }
}

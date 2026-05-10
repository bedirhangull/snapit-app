//
//  ShoppingSession.swift
//  Snap It
//

import AppKit
import Foundation

@MainActor
final class ShoppingSession: ObservableObject {
    @Published private(set) var turns: [ChatTurn] = []
    @Published private(set) var captureImage: NSImage?
    @Published private(set) var captureJPEG: Data?

    @Published private(set) var isBusy = false
    @Published var videoURL: URL?

    private let gemini = GeminiService.shared

    func handleIslandOpened(viewModel _: NotchViewModel) {
        videoURL = nil

        guard !GeminiConfig.apiKey.isEmpty else {
            captureImage = nil
            captureJPEG = nil
            resetTranscript()
            appendAssistant(
                "Set GEMINI_API_KEY in Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables, then reopen the island."
            )
            return
        }

        guard let screen = ScreenSelector.shared.selectedScreen else {
            resetTranscript()
            appendAssistant("No display found to capture.")
            return
        }

        guard let shot = ScreenshotService.capture(screen: screen) else {
            resetTranscript()
            appendAssistant(
                "Could not capture the screen. Enable Screen Recording for Snap It in System Settings → Privacy & Security."
            )
            return
        }

        captureImage = shot
        guard let jpeg = shot.jpegData(compressionQuality: 0.82) else {
            resetTranscript()
            appendAssistant("Could not encode the screen capture.")
            return
        }

        captureJPEG = jpeg

        resetTranscript()
        appendAssistant("Hang tight — I’m looking at what’s on screen…")
        isBusy = true

        Task { await analyzeCapture(jpeg: jpeg) }
    }

    func sendUserMessage(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isBusy else { return }
        guard let captureJPEG else {
            appendAssistant("No capture yet. Close and reopen the island to refresh the screenshot.")
            return
        }

        turns.append(ChatTurn(role: .user, text: text))
        isBusy = true

        Task { await chat(jpeg: captureJPEG, latestUserText: text) }
    }

    func generateTryOnClip() {
        guard !isBusy else { return }
        guard let captureJPEG else {
            appendAssistant("Capture is missing. Reopen the island.")
            return
        }
        guard let bodyJPEG = BodyPhotoManager.shared.image?.jpegData(compressionQuality: 0.88) else {
            appendAssistant("Add a body photo first (menu bar → Choose Body Photo…).")
            return
        }

        let prompt = """
Photorealistic fashion visualization. Use the subject reference for identity/body and the asset reference for the garment seen on-screen.
Soft studio lighting, neutral backdrop, subtle fabric motion. Avoid distorting the face. Fashion ecommerce preview aesthetic.
"""

        isBusy = true

        Task {
            defer { isBusy = false }
            do {
                let url = try await gemini.generateTryOnVideo(
                    prompt: prompt,
                    screenJPEG: captureJPEG,
                    bodyJPEG: bodyJPEG
                )
                videoURL = url
                appendAssistant("Rendered a try-on preview clip. If playback fails, verify API/model access in Google AI Studio.")
            } catch {
                appendAssistant("Video: \(error.localizedDescription)")
            }
        }
    }

    private func resetTranscript() {
        turns.removeAll()
    }

    private func appendAssistant(_ text: String) {
        turns.append(ChatTurn(role: .assistant, text: text))
    }

    private func replaceLastAssistant(with text: String) {
        guard let last = turns.last, last.role == .assistant else {
            appendAssistant(text)
            return
        }
        turns[turns.count - 1] = ChatTurn(id: last.id, role: .assistant, text: text)
    }

    private func analyzeCapture(jpeg: Data) async {
        defer { isBusy = false }

        do {
            let bodyJPEG = BodyPhotoManager.shared.image?.jpegData(compressionQuality: 0.88)
            let summary = try await gemini.describeVisibleOutfit(screenJPEG: jpeg, bodyJPEG: bodyJPEG)
            replaceLastAssistant(with: summary)
        } catch {
            replaceLastAssistant(with: "Couldn’t analyze the screen: \(error.localizedDescription)")
        }
    }

    private func chat(jpeg: Data, latestUserText _: String) async {
        defer { isBusy = false }

        guard turns.count >= 2 else {
            appendAssistant("Unexpected chat state.")
            return
        }

        let prior = Array(turns.dropLast())
        let historyPayload = gemini.contentsPayload(from: prior)
        let bodyJPEG = BodyPhotoManager.shared.image?.jpegData(compressionQuality: 0.88)

        do {
            let reply = try await gemini.chatReply(
                history: historyPayload,
                newUserText: turns.last!.text,
                screenJPEG: jpeg,
                bodyJPEG: bodyJPEG
            )
            turns.append(ChatTurn(role: .assistant, text: reply))
        } catch {
            turns.append(ChatTurn(role: .assistant, text: "Chat error: \(error.localizedDescription)"))
        }
    }
}

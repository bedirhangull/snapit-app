//
//  ShoppingSession.swift
//  Snap It
//

import AppKit
import Foundation

struct PendingQuery: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let query: String
}

@MainActor
final class ShoppingSession: ObservableObject {
    @Published private(set) var turns: [ChatTurn] = []
    @Published private(set) var productSections: [ProductSearchSection] = []
    @Published private(set) var isBusy = false
    @Published private(set) var loadingStatus: String?
    @Published private(set) var pendingSearchQueries: [PendingQuery] = []
    @Published private(set) var lastSearchedFor: String?
    @Published private(set) var selectedProductIDs: Set<String> = []
    @Published private(set) var comboImage: NSImage?
    @Published private(set) var comboError: String?

    private var captureJPEG: Data?
    private var productsByID: [String: Product] = [:]

    private let gemini = GeminiService.shared
    private let products = ProductSearchService.shared

    var canCreateCombo: Bool {
        !selectedProductIDs.isEmpty && !isBusy
    }

    var selectedProducts: [Product] {
        selectedProductIDs.compactMap { productsByID[$0] }
    }

    var selectedTotalApprox: Double {
        selectedProducts.compactMap(\.extractedPrice).reduce(0, +)
    }

    var hasBuyableLinks: Bool {
        selectedProducts.contains { $0.productLink != nil }
    }

    /// Screen capture + Gemini run only when the island was opened via ⌃⇧S (`.shortcut`).
    /// Click or menu opens show the existing session without new API calls.
    func handleIslandOpened(viewModel: NotchViewModel) {
        guard viewModel.openReason == .shortcut else { return }
        if isBusy { return }

        guard !GeminiConfig.apiKey.isEmpty else {
            captureJPEG = nil
            resetTranscript()
            appendAssistant(
                "Set GEMINI_API_KEY in Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables, then press ⌃⇧S again."
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

        guard let jpeg = shot.jpegData(compressionQuality: 0.82) else {
            resetTranscript()
            appendAssistant("Could not encode the screen capture.")
            return
        }

        captureJPEG = jpeg

        resetTranscript()
        isBusy = true
        loadingStatus = "Captured — analyzing your screen…"

        Task { await analyzeCapture(jpeg: jpeg) }
    }

    func sendUserMessage(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isBusy else { return }

        guard !GeminiConfig.apiKey.isEmpty else {
            turns.append(ChatTurn(role: .user, text: text))
            appendAssistant("Set GEMINI_API_KEY in Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables.")
            return
        }

        turns.append(ChatTurn(role: .user, text: text))
        isBusy = true

        if captureJPEG == nil && productSections.isEmpty {
            // Boş session → text-driven product search.
            loadingStatus = "Looking for products…"
            Task { await processTextSearch(text) }
        } else if let jpeg = captureJPEG {
            // Screenshot-based follow-up chat.
            loadingStatus = "Thinking…"
            Task { await chat(jpeg: jpeg, latestUserText: text) }
        } else {
            // Text-only follow-up after a previous text search.
            loadingStatus = "Thinking…"
            Task { await chat(jpeg: nil, latestUserText: text) }
        }
    }

    func openAllSelectedProducts() {
        for product in selectedProducts {
            guard let url = product.productLink else { continue }
            NSWorkspace.shared.open(url)
        }
    }

    func toggleProductSelection(_ id: String) {
        if selectedProductIDs.contains(id) {
            selectedProductIDs.remove(id)
        } else {
            selectedProductIDs.insert(id)
        }
    }

    func removeFromCart(_ id: String) {
        selectedProductIDs.remove(id)
    }

    func clearSelection() {
        selectedProductIDs.removeAll()
    }

    func createCombo() {
        guard canCreateCombo else { return }

        let selectedProducts = selectedProductIDs.compactMap { productsByID[$0] }
        guard !selectedProducts.isEmpty else { return }

        comboError = nil
        comboImage = nil
        isBusy = true
        loadingStatus = "Styling the outfit…"

        Task { await runComboGeneration(products: selectedProducts) }
    }

    func dismissCombo() {
        comboImage = nil
        comboError = nil
    }

    private func resetTranscript() {
        turns.removeAll()
        productSections.removeAll()
        pendingSearchQueries.removeAll()
        lastSearchedFor = nil
        selectedProductIDs.removeAll()
        comboImage = nil
        comboError = nil
        productsByID.removeAll()
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
        defer {
            isBusy = false
            loadingStatus = nil
        }

        do {
            let plan = try await gemini.extractShoppingPlan(screenJPEG: jpeg)
            appendAssistant(plan.summary)
            productSections = []
            let labelForStatus = plan.primaryLabel.isEmpty ? plan.primaryQuery : plan.primaryLabel
            loadingStatus = labelForStatus.isEmpty
                ? "Finding the best deals…"
                : "Looking for: \(labelForStatus)…"
            await runProductSearches(plan: plan)
        } catch {
            // Fallback: plain-text outfit description if the JSON path fails.
            do {
                let summary = try await gemini.describeVisibleOutfit(screenJPEG: jpeg)
                appendAssistant(summary)
                productSections = []
            } catch let inner {
                appendAssistant("Couldn’t analyze the screen: \(inner.localizedDescription)")
            }
        }
    }

    private func runProductSearches(plan: GeminiService.ShoppingPlan) async {
        let primaryQuery = plan.primaryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryQuery.isEmpty || !plan.complementary.isEmpty else { return }

        if SerpAPIConfig.apiKey.isEmpty {
            appendAssistant("Set SERPAPI_API_KEY in Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables to see shopping results.")
            return
        }

        let primaryLabel = plan.primaryLabel.isEmpty
            ? "Better deals"
            : "Better \(plan.primaryLabel.lowercased()) deals"

        var queries: [(label: String, query: String)] = []
        if !primaryQuery.isEmpty {
            queries.append((primaryLabel, primaryQuery))
        }
        for item in plan.complementary {
            queries.append((item.label, item.query))
        }

        pendingSearchQueries = queries.map { PendingQuery(label: $0.label, query: $0.query) }
        lastSearchedFor = plan.primaryLabel.isEmpty ? primaryQuery : plan.primaryLabel

        let service = products
        let results: [(Int, String, String, [Product])] = await withTaskGroup(
            of: (Int, String, String, [Product]).self
        ) { group in
            for (index, entry) in queries.enumerated() {
                group.addTask {
                    let list = (try? await service.search(query: entry.query)) ?? []
                    return (index, entry.label, entry.query, list)
                }
            }

            var collected: [(Int, String, String, [Product])] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }
        }

        let sections = results
            .filter { !$0.3.isEmpty }
            .map { ProductSearchSection(label: $0.1, query: $0.2, products: $0.3) }

        productSections = sections
        pendingSearchQueries = []

        // Merge new products into the existing cart-lookup table; keep older selected items resolvable.
        for section in sections {
            for product in section.products {
                productsByID[product.id] = product
            }
        }
    }

    private func runComboGeneration(products: [Product]) async {
        defer {
            isBusy = false
            loadingStatus = nil
        }

        // Pull thumbnails to feed Gemini as reference images.
        var thumbnails: [Data] = []
        for product in products {
            guard let url = product.thumbnail else { continue }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }
                thumbnails.append(data)
            } catch {
                continue
            }
        }

        guard !thumbnails.isEmpty else {
            comboError = "Couldn’t fetch product images for the combo."
            return
        }

        do {
            let imageData = try await gemini.generateComboImage(
                thumbnails: thumbnails,
                productTitles: products.map { $0.title }
            )
            guard let image = NSImage(data: imageData) else {
                comboError = "Generated image was not decodable."
                return
            }
            comboImage = image
        } catch {
            comboError = "Combo image failed: \(error.localizedDescription)"
        }
    }

    private func chat(jpeg: Data?, latestUserText _: String) async {
        defer {
            isBusy = false
            loadingStatus = nil
        }

        guard turns.count >= 2 else {
            appendAssistant("Unexpected chat state.")
            return
        }

        let prior = Array(turns.dropLast())
        let historyPayload = gemini.contentsPayload(from: prior)
        let latestText = turns.last!.text

        do {
            let result = try await gemini.chatWithIntent(
                history: historyPayload,
                newUserText: latestText,
                screenJPEG: jpeg
            )
            turns.append(ChatTurn(role: .assistant, text: result.reply))

            if let plan = result.newPlan {
                // Pivoted to a new shopping intent — clear ONLY the visible carousel set,
                // keep the cart (selectedProductIDs / productsByID) intact so items don't get lost.
                productSections = []
                comboImage = nil
                comboError = nil

                loadingStatus = "Looking for: \(plan.primaryLabel.isEmpty ? plan.primaryQuery : plan.primaryLabel)…"
                await runProductSearches(plan: plan)
            }
        } catch {
            turns.append(ChatTurn(role: .assistant, text: "Chat error: \(error.localizedDescription)"))
        }
    }

    private func processTextSearch(_ text: String) async {
        defer {
            isBusy = false
            loadingStatus = nil
        }

        do {
            let plan = try await gemini.extractShoppingPlanFromText(text)
            appendAssistant(plan.summary)

            if !plan.primaryQuery.isEmpty || !plan.complementary.isEmpty {
                let labelForStatus = plan.primaryLabel.isEmpty ? plan.primaryQuery : plan.primaryLabel
                loadingStatus = "Looking for: \(labelForStatus)…"
                await runProductSearches(plan: plan)
            }
        } catch {
            appendAssistant("Couldn’t parse that as a shopping intent: \(error.localizedDescription)")
        }
    }
}

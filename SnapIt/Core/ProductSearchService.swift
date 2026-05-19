//
//  ProductSearchService.swift
//  Snap It
//

import Foundation

enum SerpAPIError: LocalizedError {
    case missingAPIKey
    case badHTTP(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing SERPAPI_API_KEY environment variable."
        case .badHTTP(let code, let body):
            return "SerpAPI HTTP \(code): \(body.prefix(400))"
        case .decoding:
            return "Could not parse SerpAPI response."
        }
    }
}

final class ProductSearchService: @unchecked Sendable {
    static let shared = ProductSearchService()

    private let endpoint = URL(string: "https://serpapi.com/search.json")!

    private init() {}

    func search(query: String, limit: Int = 8) async throws -> [Product] {
        let key = SerpAPIConfig.apiKey
        guard !key.isEmpty else { throw SerpAPIError.missingAPIKey }

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "engine", value: "google_shopping"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "gl", value: "us"),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "api_key", value: key)
        ]
        guard let url = comps.url else { throw SerpAPIError.decoding }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SerpAPIError.decoding }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw SerpAPIError.badHTTP(http.statusCode, bodyText)
        }

        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let results = root["shopping_results"] as? [[String: Any]] else {
            return []
        }

        return results.prefix(limit).map { Self.decode(raw: $0) }
    }

    private static func decode(raw: [String: Any]) -> Product {
        let id = (raw["product_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
        let title = raw["title"] as? String ?? "Untitled"
        let price = raw["price"] as? String
        let extractedPrice: Double? = {
            if let d = raw["extracted_price"] as? Double { return d }
            if let i = raw["extracted_price"] as? Int { return Double(i) }
            return nil
        }()
        let oldPrice = raw["old_price"] as? String
        let source = raw["source"] as? String
        let rating: Double? = {
            if let d = raw["rating"] as? Double { return d }
            if let i = raw["rating"] as? Int { return Double(i) }
            return nil
        }()
        let reviews = raw["reviews"] as? Int
        let thumbnail = (raw["thumbnail"] as? String).flatMap { URL(string: $0) }
        let productLink = (raw["product_link"] as? String).flatMap { URL(string: $0) }
        let delivery = raw["delivery"] as? String
        let tag = raw["tag"] as? String

        return Product(
            id: id,
            title: title,
            price: price,
            extractedPrice: extractedPrice,
            oldPrice: oldPrice,
            source: source,
            rating: rating,
            reviews: reviews,
            thumbnail: thumbnail,
            productLink: productLink,
            delivery: delivery,
            tag: tag
        )
    }
}

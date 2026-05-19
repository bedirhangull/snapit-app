//
//  Product.swift
//  Snap It
//

import Foundation

struct Product: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let price: String?
    let extractedPrice: Double?
    let oldPrice: String?
    let source: String?
    let rating: Double?
    let reviews: Int?
    let thumbnail: URL?
    let productLink: URL?
    let delivery: String?
    let tag: String?
}

struct ProductSearchSection: Identifiable, Equatable, Sendable {
    let id: UUID
    let label: String
    let query: String
    let products: [Product]

    init(id: UUID = UUID(), label: String, query: String, products: [Product]) {
        self.id = id
        self.label = label
        self.query = query
        self.products = products
    }
}

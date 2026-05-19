//
//  ProductCarouselView.swift
//  Snap It
//

import SwiftUI

struct ProductCarouselView: View {
    let section: ProductSearchSection
    @ObservedObject var session: ShoppingSession

    var body: some View {
        if section.products.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(section.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text(section.query)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(section.products) { product in
                            ProductCardView(
                                product: product,
                                isSelected: session.selectedProductIDs.contains(product.id),
                                onToggleSelect: { session.toggleProductSelection(product.id) }
                            )
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
    }
}

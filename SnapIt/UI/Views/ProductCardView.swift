//
//  ProductCardView.swift
//  Snap It
//

import AppKit
import SwiftUI

struct ProductCardView: View {
    let product: Product
    let isSelected: Bool
    let onToggleSelect: () -> Void

    private let brand = Color(red: 0.678, green: 1.0, blue: 0.008)
    private let cardWidth: CGFloat = 132

    var body: some View {
        Button(action: openLink) {
            VStack(alignment: .leading, spacing: 6) {
                thumbnail
                    .frame(width: cardWidth, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? brand : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        selectionToggle
                            .padding(6)
                    }

                Text(product.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let price = product.price {
                    HStack(spacing: 6) {
                        Text(price)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(brand)
                        if let old = product.oldPrice {
                            Text(old)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .strikethrough()
                        }
                    }
                }

                metaRow
            }
            .padding(8)
            .frame(width: cardWidth + 16, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? brand.opacity(0.6) : Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = product.thumbnail {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.06)
            Image(systemName: "photo")
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var selectionToggle: some View {
        Button(action: onToggleSelect) {
            ZStack {
                Circle()
                    .fill(isSelected ? brand : Color.black.opacity(0.55))
                Circle()
                    .stroke(isSelected ? brand : Color.white.opacity(0.55), lineWidth: 1.5)
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? Color.black : Color.white)
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Remove from combo" : "Add to combo")
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 6) {
            if let source = product.source, !source.isEmpty {
                Text(source)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
            if let rating = product.rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.yellow.opacity(0.85))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            if let tag = product.tag, !tag.isEmpty {
                Text(tag)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(brand.opacity(0.85))
                    )
            }
            Spacer(minLength: 0)
        }
    }

    private func openLink() {
        guard let url = product.productLink else { return }
        NSWorkspace.shared.open(url)
    }
}

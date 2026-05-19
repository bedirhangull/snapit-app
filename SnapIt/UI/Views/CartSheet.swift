//
//  CartSheet.swift
//  Snap It
//

import SwiftUI

struct CartSheet: View {
    @ObservedObject var session: ShoppingSession
    let onCreateCombo: () -> Void
    let onBuyAll: () -> Void
    let onCancel: () -> Void

    @State private var revealedCount: Int = 0

    private let brand = Color(red: 0.678, green: 1.0, blue: 0.008)

    private var products: [Product] { session.selectedProducts }
    private var openableCount: Int { products.filter { $0.productLink != nil }.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.08))
                if products.isEmpty {
                    emptyState
                } else {
                    items
                }
                Divider().overlay(Color.white.opacity(0.08))
                footer
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear {
            revealedCount = 0
            for index in products.indices {
                let delay = Double(index) * 0.06
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        revealedCount = min(index + 1, products.count)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bag.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(brand)
            Text("Your cart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            if !products.isEmpty {
                Text("· \(products.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            if !products.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        session.clearSelection()
                    }
                } label: {
                    Text("Clear all")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bag")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.white.opacity(0.35))
            Text("Your cart is empty")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("Tap the + on a product to add it.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var items: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                    productRow(product, index: index)
                        .opacity(index < revealedCount ? 1 : 0)
                        .offset(y: index < revealedCount ? 0 : 16)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(.vertical, 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: products.count)
        }
        .frame(maxHeight: 240)
    }

    private func productRow(_ product: Product, index: Int) -> some View {
        HStack(spacing: 10) {
            thumbnail(for: product)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(product.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                if let source = product.source {
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if let price = product.price {
                Text(price)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(brand)
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    session.removeFromCart(product.id)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from cart")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    @ViewBuilder
    private func thumbnail(for product: Product) -> some View {
        if let url = product.thumbnail {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
        } else {
            Color.white.opacity(0.06)
        }
    }

    private var footer: some View {
        let total = session.selectedTotalApprox
        let canBuy = openableCount > 0 && !session.isBusy
        let canCombo = session.canCreateCombo

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text(total > 0 ? String(format: "~$%.2f", total) : "—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            Spacer(minLength: 6)

            Button(action: onCreateCombo) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text(session.comboImage == nil ? "Combo" : "Regen")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(canCombo ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                )
                .foregroundStyle(canCombo ? Color.white : Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canCombo)

            Button(action: onBuyAll) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Buy all")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(canBuy ? brand : Color.white.opacity(0.12)))
                .foregroundStyle(canBuy ? Color.black : Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canBuy)
        }
        .padding(.top, 10)
    }
}

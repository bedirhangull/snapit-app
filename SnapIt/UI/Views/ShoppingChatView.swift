//
//  ShoppingChatView.swift
//  Snap It
//

import SwiftUI

struct ShoppingChatView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var session: ShoppingSession

    @State private var draft: String = ""
    @State private var showCartSheet: Bool = false
    @FocusState private var isComposerFocused: Bool

    private let brand = Color(red: 0.678, green: 1.0, blue: 0.008)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    transcript
                    if session.isBusy, session.turns.isEmpty {
                        loadingOverlay
                    }
                }
                if session.canCreateCombo || session.comboImage != nil {
                    comboBar
                }
                composer
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            if showCartSheet {
                CartSheet(
                    session: session,
                    onCreateCombo: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showCartSheet = false
                        }
                        session.createCombo()
                    },
                    onBuyAll: {
                        session.openAllSelectedProducts()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showCartSheet = false
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showCartSheet = false
                        }
                    }
                )
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showCartSheet)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.3)
                .progressViewStyle(.circular)
            Text(session.loadingStatus ?? "Snapping it…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.turns.isEmpty, !session.isBusy {
                        Text("Press ⌃⇧S on any product page — I'll find better deals and outfit ideas.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 8)
                    }

                    ForEach(session.turns) { turn in
                        bubble(for: turn)
                            .id(turn.id)
                    }

                    if !session.productSections.isEmpty {
                        ForEach(session.productSections) { section in
                            ProductCarouselView(section: section, session: session)
                                .padding(.vertical, 4)
                        }
                    }

                    if let image = session.comboImage {
                        comboImageBubble(image)
                            .id("combo-image")
                    }

                    if let err = session.comboError {
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.85))
                            .padding(.vertical, 4)
                    }

                    if session.isBusy, !session.turns.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text(session.loadingStatus ?? "Thinking…")
                                .foregroundStyle(.white.opacity(0.55))
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 10)
            }
            .onChange(of: session.turns.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: session.isBusy) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: session.productSections.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: session.comboImage) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("combo-image", anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func comboImageBubble(_ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(brand)
                Text("Your combo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                Spacer(minLength: 0)
                Button {
                    session.dismissCombo()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.vertical, 6)
    }

    private var comboBar: some View {
        HStack(spacing: 10) {
            let count = session.selectedProductIDs.count
            let hasCombo = session.comboImage != nil

            Button {
                guard count > 0 else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    showCartSheet = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(brand)
                    Text(count > 0 ? "Cart · \(count) item\(count == 1 ? "" : "s")" : "Combo ready")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    if count > 0 {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(count > 0 ? Color.white.opacity(0.06) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .disabled(count == 0)

            Spacer(minLength: 6)

            if count > 0 {
                Button {
                    session.clearSelection()
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(session.isBusy)
            }

            if hasCombo {
                buyAllButton
            } else {
                createComboButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }

    private var createComboButton: some View {
        Button {
            session.createCombo()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("Create combo")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(session.canCreateCombo ? brand : Color.white.opacity(0.12))
            )
            .foregroundStyle(session.canCreateCombo ? Color.black : Color.white.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!session.canCreateCombo)
    }

    private var buyAllButton: some View {
        let canBuy = session.hasBuyableLinks && !session.isBusy
        let total = session.selectedTotalApprox
        let totalText = total > 0
            ? String(format: "~$%.0f", total)
            : ""
        let label = totalText.isEmpty
            ? "Buy all"
            : "Buy all · \(totalText)"

        return Button {
            guard canBuy else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                showCartSheet = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(canBuy ? brand : Color.white.opacity(0.12))
            )
            .foregroundStyle(canBuy ? Color.black : Color.white.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canBuy)
    }


    private func bubble(for turn: ChatTurn) -> some View {
        let isUser = turn.role == .user
        return HStack {
            if isUser { Spacer(minLength: 36) }

            Text(turn.text)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(isUser ? 0.95 : 0.86))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.white.opacity(0.14) : Color.white.opacity(0.07))
                )
                .multilineTextAlignment(.leading)

            if !isUser { Spacer(minLength: 36) }
        }
    }

    private var composerPlaceholder: String {
        session.turns.isEmpty
            ? "What are you shopping for? (e.g. \"I want to start running\")"
            : "Ask about sizing, styling, or alternatives…"
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(composerPlaceholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
                .focused($isComposerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .lineLimit(1 ... 4)
                .onSubmit {
                    send()
                }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(canSend ? Color.white : Color.white.opacity(0.22))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.top, 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isComposerFocused = true
            }
        }
    }

    private var canSend: Bool {
        !session.isBusy && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = draft
        draft = ""
        session.sendUserMessage(text)
    }
}

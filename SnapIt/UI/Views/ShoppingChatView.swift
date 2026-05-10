//
//  ShoppingChatView.swift
//  Snap It
//

import SwiftUI

struct ShoppingChatView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var session: ShoppingSession
    @ObservedObject private var bodyPhotos = BodyPhotoManager.shared

    @State private var draft: String = ""
    @FocusState private var isComposerFocused: Bool

    private let brand = Color(red: 0.678, green: 1.0, blue: 0.008)

    var body: some View {
        VStack(spacing: 0) {
            capturePreview

            Divider()
                .overlay(Color.white.opacity(0.08))

            transcript

            composer
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var capturePreview: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if let img = session.captureImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderTile(title: "Screen capture")
                }
            }
            .frame(width: 118, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            Group {
                if let body = bodyPhotos.image {
                    Image(nsImage: body)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderTile(title: "Body photo")
                }
            }
            .frame(width: 118, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    BodyPhotoManager.shared.pickFromDisk()
                } label: {
                    Label("Body photo", systemImage: "person.crop.square")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.white.opacity(0.14))
                .foregroundStyle(Color.white)

                Button {
                    session.generateTryOnClip()
                } label: {
                    Label("Try‑on video", systemImage: "film")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(brand.opacity(0.35))
                .foregroundStyle(Color.black)
                .disabled(session.isBusy || session.captureJPEG == nil || bodyPhotos.image == nil)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func placeholderTile(title: String) -> some View {
        ZStack {
            Color.white.opacity(0.06)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.35))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let url = session.videoURL {
                        VideoPreviewView(url: url)
                            .padding(.vertical, 4)
                    }

                    ForEach(session.turns) { turn in
                        bubble(for: turn)
                            .id(turn.id)
                    }

                    if session.isBusy {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text("Thinking…")
                                .foregroundStyle(.white.opacity(0.45))
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
        }
        .frame(maxHeight: .infinity)
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

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask about sizing, styling, or say “show me wearing this”…", text: $draft, axis: .vertical)
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

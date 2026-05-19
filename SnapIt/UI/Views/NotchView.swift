//
//  NotchView.swift
//  Snap It
//

import SwiftUI

/// Dynamic island shell. Shopping assistant UI is composed in `ShoppingChatView`.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var shoppingSession = ShoppingSession()

    private let brandColor = Color(red: 0.678, green: 1.0, blue: 0.008)

    private let cornerOpened = (top: CGFloat(19), bottom: CGFloat(24))
    private let cornerClosed = (top: CGFloat(6), bottom: CGFloat(14))

    private var closedNotchSize: CGSize {
        CGSize(width: viewModel.deviceNotchRect.width, height: viewModel.deviceNotchRect.height)
    }

    private var notchSize: CGSize {
        switch viewModel.status {
        case .closed, .popping:
            return closedNotchSize
        case .opened:
            return viewModel.openedSize
        }
    }

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened ? cornerOpened.top : cornerClosed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened ? cornerOpened.bottom : cornerClosed.bottom
    }

    private var openAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    }

    private var closeAnimation: Animation {
        .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                notchLayout
                    // Always cap width to the island size (closed = physical notch width). Never stretch to full screen.
                    .frame(width: notchSize.width, alignment: .topLeading)
                    .padding(
                        .horizontal,
                        viewModel.status == .opened ? cornerOpened.top : cornerClosed.bottom
                    )
                    .padding([.horizontal, .bottom], viewModel.status == .opened ? 12 : 0)
                    .background(.black)
                    .clipShape(
                        NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(color: viewModel.status == .opened ? .black.opacity(0.7) : .clear, radius: 6)
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width + (cornerOpened.top + 12) * 2 : nil,
                        maxHeight: viewModel.status == .opened ? notchSize.height : nil,
                        alignment: .top
                    )
                    .animation(viewModel.status == .opened ? openAnimation : closeAnimation, value: viewModel.status)
                    .animation(openAnimation, value: notchSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.status != .opened {
                            viewModel.notchOpen(reason: .click)
                        }
                    }
            }
        }
        // Center horizontally like ProdBridge: island sits above the menu bar, not a full-width bar.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            GlobalShortcutManager.shared.register(viewModel: viewModel)
        }
        .onChange(of: viewModel.status) { _, newStatus in
            if newStatus == .opened {
                shoppingSession.handleIslandOpened(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func islandMark(size: CGFloat) -> some View {
        Image(systemName: "tshirt.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(brandColor)
            .accessibilityLabel("Snap It")
    }

    @ViewBuilder
    private func activeIslandMark(size: CGFloat) -> some View {
        ZStack {
            if shoppingSession.isBusy {
                PulseHalo(color: brandColor, baseSize: size * 2.6)
            }
            islandMark(size: size)
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }

    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            if viewModel.status == .opened {
                ShoppingChatView(viewModel: viewModel, session: shoppingSession)
                    .frame(width: notchSize.width - 24)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }

    private var headerRow: some View {
        Group {
            if viewModel.status == .opened {
                HStack(spacing: 10) {
                    activeIslandMark(size: 15)

                    Text("Snap It")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))

                    if shoppingSession.isBusy {
                        Text(shoppingSession.loadingStatus ?? "Thinking…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(brandColor.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)

                    Text("⌃⇧S")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            } else {
                // Closed: compact pill — no Spacer() filling the screen width (that caused the full-width black bar).
                HStack(spacing: 8) {
                    activeIslandMark(size: 13)

                    Text(closedPillText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(shoppingSession.isBusy ? brandColor : Color.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: max(24, closedNotchSize.height))
    }

    private var closedPillText: String {
        if shoppingSession.isBusy, let status = shoppingSession.loadingStatus, !status.isEmpty {
            return status
        }
        return "Snap It"
    }
}

private struct PulseHalo: View {
    let color: Color
    let baseSize: CGFloat
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.55))
            .frame(width: baseSize, height: baseSize)
            .blur(radius: 5)
            .scaleEffect(animating ? 1.25 : 0.7)
            .opacity(animating ? 0.85 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
    }
}

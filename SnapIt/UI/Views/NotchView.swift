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
                    .frame(maxWidth: viewModel.status == .opened ? notchSize.width : nil, alignment: .top)
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
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
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

    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .frame(height: max(24, closedNotchSize.height))

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
        HStack(spacing: 10) {
            Circle()
                .fill(brandColor)
                .frame(width: 10, height: 10)

            Text("Snap It")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))

            Spacer()

            Text("⌃⇧S")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

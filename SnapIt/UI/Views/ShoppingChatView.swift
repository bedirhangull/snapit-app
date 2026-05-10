//
//  ShoppingChatView.swift
//  Snap It
//

import SwiftUI

/// Placeholder shell for commit 2; replaced with full assistant UI in the next commit.
struct ShoppingChatView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var session: ShoppingSession

    var body: some View {
        VStack(spacing: 10) {
            Text("Shopping assistant")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Gemini features ship in the following commit.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

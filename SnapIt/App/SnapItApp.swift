//
//  SnapItApp.swift
//  Snap It
//

import SwiftUI

@main
struct SnapItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

//
//  RadioApp.swift
//  Radio
//
//  Created by Vital Tatun on 3.03.26.
//

import AppKit
import SwiftUI

@main
struct RadioApp: App {
    @StateObject private var menuBarRadioPlayer = RadioPlayer()

    var body: some Scene {
        MenuBarExtra("Radio", systemImage: "dot.radiowaves.left.and.right") {
            ContentView()
                .environmentObject(menuBarRadioPlayer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}

//
//  SwabbyApp.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/13/24.
//

import SwiftUI
import AppKit
import os


let log = Logger(subsystem: "net.nardi.Swabby", category: "Swabby")

@main
struct SwabbyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: NSViewRepresentable {
    func makeNSView(context: Context) -> SwabbyView {
        SwabbyView()
    }

    func updateNSView(_ nsView: SwabbyView, context: Context) {
    }
}

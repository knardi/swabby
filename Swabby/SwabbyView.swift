//
//  SwabbyView.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import AppKit
import Foundation
import os


final class SwabbyView: NSView {
    private let renderer: Renderer
    private let sabViewSimData: OSAllocatedUnfairLock<[Float32]>

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        self.sabViewSimData = .init(initialState: [Float32](repeating: 0, count: 4 * 64)) // dt + screen width + screen height + touch count + mouse x + mouse y
        self.renderer = Renderer(
            particleCount: 1_000_000,
            sabViewSimData: sabViewSimData
        )

        super.init(frame: .zero)

        wantsLayer = true

        Task { await renderer.setRenderTarget(self) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        Task { await renderer.resize(to: frame) }
    }

    override func mouseMoved(with event: NSEvent) {
        let (x, y, height) = (event.locationInWindow.x, event.locationInWindow.y, frame.height)
        log.info("mouseMoved: \(Float32(x)), \(Float32(height) - Float32(y))")
        sabViewSimData.withLock { sabViewSimData in
            sabViewSimData[4] = Float32(x)
            sabViewSimData[5] = Float32(height) - Float32(y)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let (x, y, height) = (event.locationInWindow.x, event.locationInWindow.y, frame.height)
        log.info("mouseDown: \(Float32(x)), \(Float32(height) - Float32(y))")
        sabViewSimData.withLock { sabViewSimData in
            sabViewSimData[3] = 1
            sabViewSimData[4] = Float32(x)
            sabViewSimData[5] = Float32(height) - Float32(y)
        }
    }

    override func mouseUp(with event: NSEvent) {
        sabViewSimData.withLock { $0[3] = 0 }
    }
}

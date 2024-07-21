//
//  Worker.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import Foundation


actor Worker {
    let fixedForce: Float32 = 2583000 * 15
    var lastSetupEvent: SetupEvent? = nil
    var activeImageID: ImageID = .a
    var x: Float32 = 0
    var y: Float32 = 0

    var renderer: Renderer?

    init() {
        log.info("worker created")
    }

    func setRenderer(_ renderer: Renderer) {
        log.info("setRenderer")
        self.renderer = renderer
    }

    func postMessage(_ event: Event) async {
        log.info("postMessage")
        
        switch event {
        case .pump:
            simulate(lastSetupEvent!)
        case .setup(let setupEvent):
            lastSetupEvent = setupEvent
        }

        Task { await renderer?.onWorkerMessage() } // let the renderer know a worker is done
    }

    func simulate(_ setupEvent: SetupEvent) {
        let sabViewParticles = setupEvent.sabViewParticles
        let sabViewSimData = setupEvent.sabViewSimData
        let particleOffsetStart = setupEvent.particleOffsetStart
        let particleOffsetEnd = setupEvent.particleOffsetEnd
        let particleStride = setupEvent.particleStride
        let imageA = setupEvent.imageA
        let imageB = setupEvent.imageB

        activeImageID.toggle()
        let activeImage = switch activeImageID {
        case .a: imageA
        case .b: imageB
        }

        log.info("simulate activeImageID: \(String(describing: self.activeImageID))")

        let (delta, width, height, touchCount) = sabViewSimData.withLock { ($0[0], $0[1], $0[2], $0[3]) }

        let start = particleOffsetStart
        let end = particleOffsetEnd
        let decay = 1 / (1 + delta * 1)

        for i in start..<end {
            let pi = i * particleStride

            var (x, y, dx, dy, sx, sy) = sabViewParticles.withLock { sabViewParticles in
                (
                    sabViewParticles[pi],
                    sabViewParticles[pi + 1],
                    sabViewParticles[pi + 2] * decay,
                    sabViewParticles[pi + 3] * decay,
                    sabViewParticles[pi + 4],
                    sabViewParticles[pi + 5]
                )
            }

            if touchCount > 0 {
                for t in 0..<Int(touchCount) {
                    let (tx, ty) = sabViewSimData.withLock { ($0[4 + t * 2], $0[4 + t * 2 + 1]) }
                    forceInvSqr(tx, ty, x, y, fixedForce)
                    dx += self.x * delta * 3
                    dy += self.y * delta * 3
                }
            }

            forceSqr(sx, sy, x, y, 0.5)
            dx += self.x * delta * 1
            dy += self.y * delta * 1

            x += dx * delta
            y += dy * delta

            sabViewParticles.withLock { [x, y, dx, dy] sabViewParticles in
                sabViewParticles[pi] = x
                sabViewParticles[pi + 1] = y
                sabViewParticles[pi + 2] = dx
                sabViewParticles[pi + 3] = dy
            }

            if x < 0 || x >= width { continue }
            if y < 0 || y >= height { continue }

            activeImage.withLock { [x, y, width, height] context in
                guard
                    let context,
                    context.width == Int(width),
                    context.height == Int(height),
                    let data = context.data
                else {
                    log.info("image size doesn't match sabViewSimData")
                    return
                }

                let buffer = UnsafeMutableRawBufferPointer(start: data, count: Int(width) * Int(height) * 4)
                let pixelIndex = (Int(y) * Int(width) + Int(x)) * 4
                buffer[pixelIndex] = min(buffer[pixelIndex] &+ 30, 255) // Red channel
                buffer[pixelIndex + 1] = min(buffer[pixelIndex + 1] &+ 40, 255) // Green channel
                buffer[pixelIndex + 2] = min(buffer[pixelIndex + 2] &+ 65, 255) // Blue channel
                buffer[pixelIndex + 3] = 255 // Alpha channel (opacity)
            }
        }
    }

    func forceInvSqr(_ x1: Float32, _ y1: Float32, _ x2: Float32, _ y2: Float32, _ m: Float32 = 25830000) {
        let dx = x1 - x2
        let dy = y1 - y2
        let dist = sqrt(dx * dx + dy * dy)
        let dirX = dx / dist
        let dirY = dy / dist
        let force = min(1200, m / (dist * dist))
        self.x = force * dirX
        self.y = force * dirY
    }

    func forceSqr(_ x1: Float32, _ y1: Float32, _ x2: Float32, _ y2: Float32, _ d: Float32 = 999999) {
        let dx = x1 - x2
        let dy = y1 - y2
        let dist = sqrt(dx * dx + dy * dy)
        if (d <= dist) {
            let dirX = dx / dist
            let dirY = dy / dist
            let force = min(12000, dist * dist)
            self.x = force * dirX
            self.y = force * dirY
            return
        }
        self.x = 0
        self.y = 0
    }
}

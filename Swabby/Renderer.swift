//
//  Renderer.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import AppKit
import CoreGraphics
import Foundation
import os
import QuartzCore


actor Renderer {
    private let particleCount: Int
    private let workerCount: Int
    private let workerChunkSize: Int

    private var simData: SimData
    private var lastTime = CFAbsoluteTime()

    private let particleStride: Int
    private let particleByteStride: Int
    private let sabViewParticles: OSAllocatedUnfairLock<[Float32]>
    private let sabViewSimData: OSAllocatedUnfairLock<[Float32]>

    var renderTarget: NSView? = nil

    init(
        particleCount: Int,
        sabViewSimData: OSAllocatedUnfairLock<[Float32]>
    ) {
        self.particleCount = particleCount
        self.sabViewSimData = sabViewSimData

        self.workerCount = ProcessInfo().processorCount
        self.workerChunkSize = particleCount / workerCount

        let imageA = OSAllocatedUnfairLock<CGContext?>(initialState: nil)
        let imageB = OSAllocatedUnfairLock<CGContext?>(initialState: nil)

        self.simData = SimData(
            workerPool: (0..<workerCount).map { _ in Worker() },
            activeWorkers: workerCount,
            width: 0,
            height: 0,
            imageA: imageA,
            imageB: imageB,
            activeImage: .init(initialState: ImageID.a)
        )

        self.particleStride = 6 // 6 floats x,y,dx,dy,sx,sy
        self.particleByteStride = particleStride * 4 // 4 bytes per float
        self.sabViewParticles = .init(initialState: [Float32](repeating: 0, count: particleCount * particleByteStride))

        Task {
            for worker in await simData.workerPool {
                await worker.setRenderer(self)
            }
        }
    }

    func setRenderTarget(_ renderTarget: NSView) {
        log.info("setRenderTarget")
        self.renderTarget = renderTarget
    }

    func resize(to frame: CGRect) {
        log.info("resize")

        guard frame.width != 0 && frame.height != 0 else {
            return
        }

        let fwidth = Float32(frame.width)
        let fheight = Float32(frame.height)
        let width = Int(frame.width)
        let height = Int(frame.height)

        simData.width = frame.width
        simData.height = frame.height

        sabViewSimData.withLock {
            $0[1] = Float32(fwidth)
            $0[2] = Float32(fheight)
        }

        let (gridA, gridB) = (makeBuffer(width: width, height: height), makeBuffer(width: width, height: height))
        simData.imageA.withLock { $0 = gridA }
        simData.imageB.withLock { $0 = gridB }

        sabViewParticles.withLock { [particleCount] sabViewParticles in
            for i in 0..<particleCount {
                sabViewParticles[i * particleStride] = Float32.random(in: 0..<fwidth)
                sabViewParticles[i * particleStride + 1] = Float32.random(in: 0..<fheight)
                sabViewParticles[i * particleStride + 2] = Float32.random(in: -30...30)
                sabViewParticles[i * particleStride + 3] = Float32.random(in: -30...30)
                sabViewParticles[i * particleStride + 4] = sabViewParticles[i * particleStride]
                sabViewParticles[i * particleStride + 5] = sabViewParticles[i * particleStride + 1]
            }
        }

        for (i, worker) in simData.workerPool.enumerated() {
            Task {
                await worker.postMessage(
                    .setup(.init(
                        sabViewParticles: sabViewParticles,
                        sabViewSimData: sabViewSimData,
                        particleOffsetStart: workerChunkSize * i,
                        particleOffsetEnd: workerChunkSize * i + workerChunkSize,
                        particleStride: particleStride,
                        imageA: simData.imageA,
                        imageB: simData.imageB
                    ))
                )
            }
        }
    }

    func onWorkerMessage() async {
        log.info("onWorkerMessage")

        simData.activeWorkers -= 1
        if simData.activeWorkers > 0 {
            return
        }

        runSimulation(currentTime: CFAbsoluteTimeGetCurrent())
    }

    func runSimulation(currentTime: CFTimeInterval) {
        log.info("runSimulation")

        let dt = min(0.1, (currentTime - lastTime) / 1000)
        lastTime = currentTime
        sabViewSimData.withLock { $0[0] = Float32(dt) }
        simData.activeWorkers = workerCount

        for worker in simData.workerPool {
            Task { await worker.postMessage(.pump) }
        }

        let activeImageID = simData.activeImage.withLock { activeImage in
            activeImage.toggle()
            return activeImage
        }

        let activeImage = switch activeImageID {
            case .a: simData.imageA
            case .b: simData.imageB
        }

        log.info("render activeImageID: \(String(describing: activeImageID))")

        render(image: activeImage)
    }

    func render(image: OSAllocatedUnfairLock<CGContext?>) {
        log.info("render")
        
        guard let renderTarget else { return }
        let image = image.withLock { context -> CGImage? in
            guard let context else { return nil }
            let image = context.makeImage()!
            context.data?.initializeMemory(as: UInt8.self, repeating: 0, count: context.width * context.height * 4)
            return image
        }

        guard let image else {
            log.warning("no image to render")
            return
        }

        Task { @MainActor in
            renderTarget.layer!.contents = image
            renderTarget.needsDisplay = true
        }
    }

    private func makeBuffer(width: Int, height: Int) -> CGContext {
        return CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 4 * Int(width),
            space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
    }
}

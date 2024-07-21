//
//  SetupEvent.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import CoreGraphics
import Foundation
import os


struct SetupEvent {
    let sabViewParticles: OSAllocatedUnfairLock<[Float32]>
    let sabViewSimData: OSAllocatedUnfairLock<[Float32]>
    let particleOffsetStart: Int
    let particleOffsetEnd: Int
    let particleStride: Int
    let imageA: OSAllocatedUnfairLock<CGContext?>
    let imageB: OSAllocatedUnfairLock<CGContext?>
}

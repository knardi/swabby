//
//  SimData.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import CoreGraphics
import Foundation
import os


struct SimData {
    var workerPool: [Worker]
    var activeWorkers: Int
    var width: CGFloat
    var height: CGFloat
    var imageA: OSAllocatedUnfairLock<CGContext?>
    var imageB: OSAllocatedUnfairLock<CGContext?>
    var activeImage: OSAllocatedUnfairLock<ImageID>
}

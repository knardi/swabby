//
//  MessageQueue.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import Foundation
import os


struct MessageQueue<T> {
    private let messages: OSAllocatedUnfairLock<[T]> = .init(initialState: [])
    private let receiveMessage = NSCondition()

    func push(_ message: T) {
        messages.withLock { $0.insert(message, at: 0) }
        receiveMessage.signal()
    }

    func waitForMessage() -> T {
        while true {
            receiveMessage.wait()
            if let message = messages.withLock({ $0.popLast() }) {
                return message
            }
        }
    }
}

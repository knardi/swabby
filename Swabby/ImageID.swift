//
//  ImageID.swift
//  Swabby
//
//  Created by Kevin Nardi on 7/18/24.
//

import Foundation


enum ImageID {
    case a, b

    mutating func toggle() {
        switch self {
        case .a:
            self = .b
        case .b:
            self = .a
        }
    }
}

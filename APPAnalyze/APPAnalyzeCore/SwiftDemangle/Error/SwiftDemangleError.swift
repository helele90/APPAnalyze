//
//  SwiftDemangleError.swift
//  SwiftDemangle
//
//  Created by spacefrog on 2021/06/24.
//

import Foundation

public enum SwiftDemangleError: Error {
    case oldDemanglerError(description: String, nodeDebugDescription: String)
    case newDemanglerError(description: String, nodeDebugDescription: String)
    case nodePrinterError(description: String, nodeDebugDescription: String)
}

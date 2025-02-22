//
//  MangledDifferentiabilityKind.swift
//  Demangling
//
//  Created by spacefrog on 2021/05/18.
//

import Foundation

enum MangledDifferentiabilityKind: String {
    case nonDifferentiable = ""
    case forward = "f"
    case reverse = "r"
    case normal = "d"
    case linear = "l"
}

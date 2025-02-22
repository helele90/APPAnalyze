//
//  ReferenceOwnership.swift
//  Demangling
//
//  Created by spacefrog on 2021/04/02.
//

import Foundation

enum ReferenceOwnership: String {
    case strong
    case weak
    case unowned
    case unmanaged = "unowned(unsafe)"
}

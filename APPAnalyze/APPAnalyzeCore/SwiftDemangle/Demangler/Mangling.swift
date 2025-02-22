//
//  Mangling.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/06.
//

import Foundation

protocol Mangling {
    var maxRepeatCount: Int { get }
    
    func isOldFunctionType<S>(_ name: S) -> Bool where S: StringProtocol
    func manglingPrefixLength<S>(from mangled: S) -> Int where S: StringProtocol
}

extension Mangling {
    var maxRepeatCount: Int { 2048 }
    
    func isOldFunctionType<S>(_ name: S) -> Bool where S: StringProtocol {
        name.hasPrefix("_T")
    }
    
    func manglingPrefixLength<S>(from mangled: S) -> Int where S: StringProtocol {
        if mangled.isEmpty {
            return 0
        } else {
            let prefixes = [
                "_T0",          // swift 4
                "$S", "_$S",    // swift 4.*
                "$s", "_$s"     // swift 5+.*
            ]
            for prefix in prefixes where mangled.hasPrefix(prefix){
                return prefix.count
            }
            return 0
        }
    }
}

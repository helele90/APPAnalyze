//
//  BinaryInteger+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/04/01.
//

import Foundation

extension BinaryInteger {
    
    var hex: String {
        String(self, radix: 16, uppercase: false)
    }
    
    var HEX: String {
        String(self, radix: 16, uppercase: true)
    }
    
    var bit: String {
        String(self, radix: 2)
    }
    
    mutating func advancing(by n: Int) -> Self {
        self = self.advanced(by: n)
        return self
    }
    
    mutating func advancedAfter(by n: Int = 1) -> Self {
        defer {
            self = self.advanced(by: n)
        }
        return self
    }
}

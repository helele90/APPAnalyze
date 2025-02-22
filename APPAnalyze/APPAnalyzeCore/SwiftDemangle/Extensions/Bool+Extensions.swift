//
//  Bool+Extensions.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/02.
//

import Foundation

extension Bool {
    
    mutating func changing(_ value: Bool) -> Bool {
        self = value
        return self
    }
    
    @discardableResult
    func bind(to: inout Bool) -> Bool {
        to = self
        return self
    }
    
    var not: Bool {
        !self
    }
}

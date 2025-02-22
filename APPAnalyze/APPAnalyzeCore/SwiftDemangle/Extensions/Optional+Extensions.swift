//
//  Optional+Map.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/29.
//

import Foundation

extension Optional {
    
    func map<Value>(_ keyPath: KeyPath<Wrapped, Value>) -> Value? {
        if let wrapped = self {
            return wrapped[keyPath: keyPath]
        } else {
            return nil
        }
    }

    func or(_ defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }
    
    var hasValue: Bool {
        self != nil
    }
    
}

extension Optional where Wrapped: Collection {
    
    var isEmptyOrNil: Bool {
        self?.isEmpty ?? true
    }
    
    var isNotEmpty: Bool {
        self?.isNotEmpty ?? false
    }
    
}

prefix func !<W>(rhs: Optional<W>) -> Bool {
    rhs.hasValue.not
}

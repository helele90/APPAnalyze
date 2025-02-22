//
//  Collection+Extensions.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/30.
//

import Foundation

extension Collection {
    
    var isNotEmpty: Bool {
        !isEmpty
    }
    
    func emptyToNil() -> Self? {
        if isEmpty {
            return nil
        } else {
            return self
        }
    }
    
}

protocol CollectionOptional {
    associatedtype Wrapped
    var wrappedValue: Wrapped? { get }
}

extension Optional: CollectionOptional {
    var wrappedValue: Wrapped? {
        if let value = self {
            return value
        } else {
            return nil
        }
    }
}

extension Set where Element: CollectionOptional, Element.Wrapped: Hashable {
    func flatten() -> Set<Element.Wrapped> {
        Set<Element.Wrapped>(self.compactMap(\.wrappedValue))
    }
}

extension Array where Element: CollectionOptional {
    func flatten() -> Array<Element.Wrapped> {
        Array<Element.Wrapped>(self.compactMap(\.wrappedValue))
    }
}


extension BidirectionalCollection where Index: BinaryInteger {
    
    func interleave(eachHandle: (Index, Element) throws -> Void, betweenHandle: () throws -> Void) throws {
        var index = self.startIndex
        if let first = self.first {
            try eachHandle(index, first)
        }
        try dropFirst().forEach { element in
            try betweenHandle()
            index += 1
            try eachHandle(index, element)
        }
    }
    
}

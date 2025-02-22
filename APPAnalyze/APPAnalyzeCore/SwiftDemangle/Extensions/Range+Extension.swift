//
//  Range+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/05/19.
//

import Foundation

extension ClosedRange {
    func boundTo<To>(_ keyPath: KeyPath<Bound, To>) -> ClosedRange<To> where To: Comparable {
        (self.lowerBound[keyPath: keyPath]...self.upperBound[keyPath: keyPath])
    }
}

extension Range {
    func boundTo<To>(_ keyPath: KeyPath<Bound, To>) -> Range<To> where To: Comparable {
        (self.lowerBound[keyPath: keyPath]..<self.upperBound[keyPath: keyPath])
    }
}

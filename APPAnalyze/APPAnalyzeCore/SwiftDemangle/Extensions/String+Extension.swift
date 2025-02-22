//
//  String+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/04/02.
//

import Foundation

extension String {
    func lowercasedOnlyFirst() -> String {
        var string = self
        return string.removeFirst().lowercased() + string
    }
    
    var character: Character { self.first ?? .zero }
}

public protocol StringIntegerIndexable: StringProtocol {
    subscript(_ indexRange: Range<Int>) -> Substring { get }
    subscript(r: Range<Self.Index>) -> Substring { get }
}

extension StringIntegerIndexable {
    public subscript(_ index: Int) -> Character {
        self[self.index(self.startIndex, offsetBy: index)]
    }
    public subscript(_ indexRange: Range<Int>) -> Substring {
        guard indexRange.lowerBound >= 0, indexRange.upperBound <= self.count else { return "" }
        let range = Range<Self.Index>(uncheckedBounds: (self.index(self.startIndex, offsetBy: indexRange.lowerBound), self.index(self.startIndex, offsetBy: indexRange.upperBound)))
        return self[range]
    }
}

extension String: StringIntegerIndexable {}
extension Substring: StringIntegerIndexable {}

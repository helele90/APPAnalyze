//
//  Character+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/05/19.
//

import Foundation

extension Character {
    
    static let zero: Character = Character(.init(UInt8.zero))
    
    var isDigit: Bool {
        self.unicodeScalars.first.map(CharacterSet.decimalDigits.contains) ?? false
    }
    
    func isWordEnd(prevChar: Character? = nil) -> Bool {
        if self == "_" || self == .zero {
            return true
        } else if let prevChar = prevChar, !prevChar.isUppercase, self.isUppercase {
            return true
        } else {
            return false
        }
    }
    
    var isWordStart: Bool {
        !isDigit && self != "_" && self != .zero
    }
    
    func number<Number>(_ type: Number.Type) -> Number? where Number: FixedWidthInteger {
        Number(String(self))
    }
    
    var mangledDifferentiabilityKind: MangledDifferentiabilityKind? {
        return MangledDifferentiabilityKind(rawValue: String(self))
    }
}

func ~= (pattern: UInt8, char: Character) -> Bool {
    char.asciiValue == pattern
}

func ~= (pattern: UInt8, char: Character?) -> Bool {
    char?.asciiValue == pattern
}

func - (lhs: Character, rhs: Character) -> Int {
    Int(lhs.asciiValue.or(0)) - Int(rhs.asciiValue.or(0))
}

func + (lhs: Character, rhs: UInt8) -> Character {
    if let value = lhs.asciiValue {
        return Character(.init(value + rhs))
    } else {
        return lhs
    }
}

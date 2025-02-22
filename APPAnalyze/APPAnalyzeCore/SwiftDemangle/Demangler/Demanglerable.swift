//
//  Demanglerable.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/06.
//

import Foundation

protocol Demanglerable: AnyObject {
    var mangled: Data { get set }
    var mangledOriginal: Data { get }
    var text: String { get }
    var textOriginal: String { get }
    var numerics: [Character] { get }
    var substitutions: [Node] { get }
    
    init(_ mangled: String)
}

extension Demanglerable {
    
    var text: String {
        String(data: self.mangled, encoding: .ascii) ?? ""
    }
    
    var textOriginal: String {
        String(data: self.mangledOriginal, encoding: .ascii) ?? ""
    }
    
    func peekChar() -> Character {
        if let ascii = mangled.first {
            return Character.init(.init(ascii))
        } else {
            return .zero
        }
    }
    
    func nextNumber<BI>(_ type: BI.Type) -> BI? where BI: BinaryInteger {
        let size = MemoryLayout<BI>.size
        if size <= mangled.count {
            let pref = mangled[0..<size]
            mangled.removeFirst(size)
            return pref.withUnsafeBytes({ $0.load(as: BI.self) })
        } else {
            return nil
        }
    }
    
    @discardableResult
    func nextChar() -> Character {
        guard mangled.count < mangledOriginal.count else { return .zero }
        return Character(.init(mangled.removeFirst()))
    }
    
    func nextString(_ prefixLength: Int) -> String {
        let length = min(prefixLength, mangled.count)
        guard length > 0 else { return String(data: mangled, encoding: .ascii) ?? "" }
        
        let next = mangled[0..<length]
        mangled.removeFirst(length)
        return String(data: next, encoding: .ascii) ?? ""
    }
    
    func nextIf(_ character: Character) -> Bool {
        if peekChar() == character {
            mangled.removeFirst()
            return true
        } else {
            return false
        }
    }
    
    func peek() -> Character {
        mangled.first.flatMap({ Character(.init($0)) }) ?? "."
    }
    
    var isEmpty: Bool {
        mangled.isEmpty
    }
    
    var isNotEmpty: Bool {
        mangled.isNotEmpty
    }
    
    func nextIf(_ pref: String) -> Bool {
        let prefData: Data = pref.data(using: .ascii) ?? Data()
        if prefData.count <= mangled.count, mangled.subdata(in: 0..<prefData.count) == prefData {
            self.mangled = Data(self.mangled.subdata(in: prefData.count..<mangled.count))
            return true
        } else {
            return false
        }
    }
    
    @discardableResult
    func next() -> Character? {
        let peeked = peek()
        if !self.mangled.isEmpty {
            self.mangled = Data(self.mangled.dropFirst())
        }
        return peeked
    }
    
    func readUntil(_ c: Character) -> String {
        var result: String = ""
        while !isEmpty, let peeked = peek().notEqualOrNil(c) {
            result.append(peeked.description)
            advanceOffset(1)
        }
        return result
    }
    
    func slice(_ length: Int) -> String {
        String(data: mangled[mangled.startIndex..<mangled.index(mangled.startIndex, offsetBy: length)], encoding: .ascii) ?? ""
    }
    
    func advanceOffset(_ length: Int) {
        mangled = Data(mangled.dropFirst(length))
    }
    
    func hasAtLeast(_ length: UInt64) -> Bool {
        length <= mangledOriginal.count
    }
    
    func isStartOfEntity(_ character: Character?) -> Bool {
        switch character {
        case "F", "I", "v", "P", "s", "Z":
            return true
        default:
            return isStartOfNominalType(character)
        }
    }
    
    func isStartOfIdentifier(_ character: Character) -> Bool {
        numerics.contains(character) || character == "o"
    }
    
    func isStartOfNominalType(_ character: Character?) -> Bool {
        switch character {
        case "C", "V", "O":
            return true
        default:
            return false
        }
    }
    
    func nominalTypeMarkerToNodeKind(_ character: Character) -> Node.Kind {
        switch character {
        case "C":
            return .Class
        case "V":
            return .Structure
        case "O":
            return .Enum
        default:
            return .Identifier
        }
    }
    
    func consumeAll() -> String {
        let text = self.mangled
        self.mangled = Data()
        return String(data: text, encoding: .ascii) ?? ""
    }
    
}

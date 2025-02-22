//
//  String+Demangling.swift
//  SwiftDemangle
//
//  Created by spacefrog on 2021/06/27.
//

import Foundation

public extension String {
    
    var demangled: String {
        guard let demangled = try? self.demangling(.defaultOptions) else { return self }
        return demangled
    }
    
    func demangling(_ options: DemangleOptions) throws -> String {
        var mangled = self
        if mangled.hasPrefix("S") || mangled.hasPrefix("s") {
            mangled = "$" + mangled
        }
        guard let regex = try? NSRegularExpression(pattern: "[^ \n\r\t<>;:]+", options: []) else { return self }
        return try regex.matches(in: mangled, options: [], range: NSRange(mangled.startIndex..<mangled.endIndex, in: mangled)).reversed().reduce(mangled, { (text, match) -> String in
            if let range = Range<String.Index>.init(match.range, in: text) {
                let demangled = try text[range].demangleSymbolAsString(with: options)
                return text.replacingCharacters(in: range, with: demangled)
            } else {
                return text
            }
        })
    }
    
}

//
//  String+Extension.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/28.
//

import Foundation

extension String {
    
    /// 字符串按行读取
    /// - Parameter callback: 回调
    func lines(callback: (String, Int) -> Void) {
        var line = ""
        var indent = 0
        for char in self {
            if char == "\n" || char == "\r\n" {
                callback(line, indent / 4)
                assert(indent % 4 == 0)
                line = ""
                indent = 0
            } else {
                if char != " " || !line.isEmpty {
                    line.append(char)
                } else if char == " " {
                    indent += 1
                }
            }
        }
        //
        if !line.isEmpty {
            callback(line, indent / 4)
            assert(indent % 4 == 0)
        }
        #warning("返回 substring 提高性能")
    }

    
    /// 字符串按行读取
    /// - Parameter callback: 回调
    public func lines(callback: (String) -> Void) {
        var line = ""
        for char in self {
            if char == "\n" || char == "\r\n" {
                callback(line)
                line = ""
            } else {
                if char != " " || !line.isEmpty {
                    line.append(char)
                }
            }
        }
        //
        if !line.isEmpty {
            callback(line)
        }
    }

    public var fileName: String {
        guard let index = lastIndex(of: ".") else {
            return self
        }

        let fileName = String(self[startIndex ..< index])
        if fileName.count == count || count - fileName.count > 5 {
            return self
        }

        return fileName
    }

    var swiftClassNamesDemangled: [String] {
        if !hasPrefix("_T"), !hasPrefix("_$") {
            return [self]
        }
        //
        let demangled = classDemangling()
        //
        return demangled
    }

    var swiftProtocolName: String {
        if !hasPrefix("_T") && !hasPrefix("s") {
            return self
        }
        //
        let demangled = self.demangled
        return demangled.isEmpty ? self : demangled
    }

    var swiftClassNameDemangled: String {
        if !hasPrefix("_T") && !hasPrefix("s") {
            return self
        }
        //
        let options = DemangleOptions.defaultOptions

        let demangled = (try? demangling(options)) ?? ""
        if demangled.hasPrefix("type metadata accessor for") {
            let startIndex = demangled.index(demangled.startIndex, offsetBy: 27)
            return String(demangled[startIndex ..< demangled.endIndex])
        } else if demangled.hasPrefix("type metadata for") {
            let startIndex = demangled.index(demangled.startIndex, offsetBy: 18)
            return String(demangled[startIndex ..< demangled.endIndex])
        } else if demangled.hasPrefix("full type metadata for") {
            let startIndex = demangled.index(demangled.startIndex, offsetBy: 23)
            return String(demangled[startIndex ..< demangled.endIndex])
        }

        return demangled
    }
}

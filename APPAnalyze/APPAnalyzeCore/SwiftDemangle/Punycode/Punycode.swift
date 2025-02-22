//
//  Punycode.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/03.
//

import Foundation

struct Punycode {
    
    let string: String
    
    func decode() -> String? {
        guard let decoded = decodePunycode(string) else { return nil }
        return encode(decoded)
    }
    
    func decodePunycode(_ InputPunycode: String) -> [UInt32]? {
        
        var InputPunycode = InputPunycode
        
        let base         = 36
        let tmin         = 1
        let tmax         = 26
        let skew         = 38
        let damp         = 700
        let initial_bias = 72
        let initial_n = 128
        let delimeter = "_"
        
        func adapt(_ delta: Int, _ numpoints: Int, _ firsttime: Bool) -> Int {
            var delta = delta
            if firsttime {
                delta = delta / damp
            } else {
                delta = delta / 2
            }
          
            delta += delta / numpoints
            var k = 0
            while delta > ((base - tmin) * tmax) / 2 {
                delta /= base - tmin
                k += base
            }
            return k + (((base - tmin + 1) * delta) / (delta + skew))
        }
        
        var OutCodePoints: [UInt32] = []
        
        // -- Build the decoded string as UTF32 first because we need random access.
        var n = initial_n
        var i = 0
        var bias = initial_bias
        /// let output = an empty string indexed from 0
        // consume all code points before the last delimiter (if there is one)
        //  and copy them to output,
        let lastDelimeter = InputPunycode.range(of: delimeter, options: .backwards)
        if let lastDelimiter = lastDelimeter {
            for character in InputPunycode[InputPunycode.startIndex..<lastDelimiter.lowerBound] {
                // fail on any non-basic code point
                if character.asciiValue.or(0) > 0x7f {
                    return nil
                }
                if let value = character.asciiValue {
                    OutCodePoints.append(UInt32(value))
                }
            }
            // if more than zero code points were consumed then consume one more
            //  (which will be the last delimiter)
            InputPunycode = String(InputPunycode[InputPunycode.index(after: lastDelimiter.lowerBound)..<InputPunycode.endIndex])
        }
        
        while InputPunycode.isNotEmpty {
            let oldi = i
            var w = 1
            var k = base
            while true {
                defer {
                    k += base
                }
                // consume a code point, or fail if there was none to consume
                if InputPunycode.isEmpty {
                    return nil
                }
                let codePoint = InputPunycode.removeFirst()
                // let digit = the code point's digit-value, fail if it has none
                let digit = codePoint.digitIndex()
                if digit < 0 {
                    return nil
                }
                
                // Fail if i + (digit * w) would overflow
                if digit > (Int.max - i) / w {
                    return nil
                }
                
                i = i + digit * w
                let t: Int
                if k <= bias {
                    t = tmin
                } else {
                    if k >= bias + tmax {
                        t = tmax
                    } else {
                        t = k - bias
                    }
                }
                if digit < t {
                    break
                }
                // Fail if w * (base - t) would overflow
                if w > Int.max / (base - t) {
                    return nil
                }
                w = w * (base - t)
            }
            bias = adapt(i - oldi, OutCodePoints.count + 1, oldi == 0)
            // Fail if n + i / (OutCodePoints.size() + 1) would overflow
            if i / (OutCodePoints.count + 1) > Int.max - Int(n) {
                return nil
            }
            n = n + i / (OutCodePoints.count + 1)
            i = i % (OutCodePoints.count + 1)
            // if n is a basic code point then fail
            if n < 0x80 {
                return nil
            }
            // insert n into output at position i
            OutCodePoints.insert(UInt32(n), at: i)
            i += 1
        }
        
        return OutCodePoints
    }
    
    func encode(_ value: [UInt32]) -> String? {
        var encoded = Data()
        for scalar in value {
            var scalar = scalar
            guard scalar.isValidUnicodeScalar else { return nil }
            if scalar >= 0xD800 && scalar < 0xD880 {
                scalar -= 0xD800
            }

            var bytes: UInt = 0
            switch scalar {
            case ..<0x80:
                bytes = 1
            case ..<0x800:
                bytes = 2
            case ..<0x10000:
                bytes = 3
            default:
                bytes = 4
            }
            
            switch bytes {
            case 1:
                encoded.append(UInt8(scalar))
            case 2:
                let byte2: UInt8 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte1 = UInt8(scalar | 0xC0)
                encoded.append(byte1)
                encoded.append(byte2)
            case 3:
                let byte3 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte2 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte1 = UInt8(scalar | 0xE0)
                encoded.append(byte1)
                encoded.append(byte2)
                encoded.append(byte3)
            case 4:
                let byte4 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte3 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte2 = UInt8((scalar | 0x80) & 0xBF)
                scalar >>= 6
                let byte1 = UInt8(scalar | 0xE0)
                encoded.append(byte1)
                encoded.append(byte2)
                encoded.append(byte3)
                encoded.append(byte4)
            default:
                break
            }
        }
        return String(data: encoded, encoding: .utf8)
    }

    
}

private extension UInt32 {
    var isValidUnicodeScalar: Bool {
        if self < 0xD880 {
            return true
        } else {
            return self >= 0xE000 && self <= 0x10FFFF
        }
    }
}

private extension String {
    mutating func append(_ scalar: UInt32) {
        guard let scalar = UnicodeScalar(scalar) else { return }
        self.append(Character(scalar))
    }
}

private extension Character {
    
    func digitIndex() -> Int {
        if self >= "a" && self <= "z" {
            return self - "a"
        }
        if self >= "A" && self <= "J" {
            return self - "A" + 26
        }
        return -1
    }
    
}

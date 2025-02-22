//
//  StandardType.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/09.
//

import Foundation

enum StandardType: Character, CaseIterable {
    case a = "a"
    case b = "b"
    case D = "D"
    case d = "d"
    case f = "f"
    case h = "h"
    case I = "I"
    case i = "i"
    case J = "J"
    case N = "N"
    case n = "n"
    case O = "O"
    case P = "P"
    case p = "p"
    case R = "R"
    case r = "r"
    case S = "S"
    case s = "s"
    case u = "u"
    case V = "V"
    case v = "v"
    case W = "W"
    case w = "w"

    case q = "q"

    case B = "B"
    case E = "E"
    case e = "e"
    case F = "F"
    case G = "G"
    case H = "H"
    case j = "j"
    case K = "K"
    case k = "k"
    case L = "L"
    case l = "l"
    case M = "M"
    case m = "m"
    case Q = "Q"
    case T = "T"
    case t = "t"
    case U = "U"
    case X = "X"
    case x = "x"
    case Y = "Y"
    case y = "y"
    case Z = "Z"
    case z = "z"
    
    var kind: Node.Kind {
        switch self {
        case .a, .b, .D, .d, .f, .h, .I, .i, .J, .N, .n, .O, .P, .p, .R, .r, .S, .s, .u, .V, .v, .W, .w: return .Structure
        case .q: return .Enum
        case .B, .E, .e, .F, .G, .H, .j, .K, .k, .L, .l, .M, .m, .Q, .T, .t, .U, .X, .x, .Y, .y, .Z, .z: return .Protocol
        }
    }
    
    var typeName: String {
        switch self {
        case .a: return "Array"
        case .b: return "Bool"
        case .D: return "Dictionary"
        case .d: return "Double"
        case .f: return "Float"
        case .h: return "Set"
        case .I: return "DefaultIndices"
        case .i: return "Int"
        case .J: return "Character"
        case .N: return "ClosedRange"
        case .n: return "Range"
        case .O: return "ObjectIdentifier"
        case .P: return "UnsafePointer"
        case .p: return "UnsafeMutablePointer"
        case .R: return "UnsafeBufferPointer"
        case .r: return "UnsafeMutableBufferPointer"
        case .S: return "String"
        case .s: return "Substring"
        case .u: return "UInt"
        case .V: return "UnsafeRawPointer"
        case .v: return "UnsafeMutableRawPointer"
        case .W: return "UnsafeRawBufferPointer"
        case .w: return "UnsafeMutableRawBufferPointer"
            
        case .q: return "Optional"
            
        case .B: return "BinaryFloatingPoint"
        case .E: return "Encodable"
        case .e: return "Decodable"
        case .F: return "FloatingPoint"
        case .G: return "RandomNumberGenerator"
        case .H: return "Hashable"
        case .j: return "Numeric"
        case .K: return "BidirectionalCollection"
        case .k: return "RandomAccessCollection"
        case .L: return "Comparable"
        case .l: return "Collection"
        case .M: return "MutableCollection"
        case .m: return "RangeReplaceableCollection"
        case .Q: return "Equatable"
        case .T: return "Sequence"
        case .t: return "IteratorProtocol"
        case .U: return "UnsignedInteger"
        case .X: return "RangeExpression"
        case .x: return "Strideable"
        case .Y: return "RawRepresentable"
        case .y: return "StringProtocol"
        case .Z: return "SignedInteger"
        case .z: return "BinaryInteger"
        }
    }
}

enum StandardTypeConcurrency: Character, CaseIterable {
    case A = "A"
    case C = "C"
    case c = "c"
    case E = "E"
    case e = "e"
    case F = "F"
    case f = "f"
    case G = "G"
    case g = "g"
    case I = "I"
    case i = "i"
    case J = "J"
    case M = "M"
    case P = "P"
    case S = "S"
    case s = "s"
    case T = "T"
    case t = "t"
    
    var kind: Node.Kind {
        switch self {
        case .A: return .Protocol
        case .C: return .Structure
        case .c: return .Structure
        case .E: return .Structure
        case .e: return .Structure
        case .F: return .Protocol
        case .f: return .Protocol
        case .G: return .Structure
        case .g: return .Structure
        case .I: return .Protocol
        case .i: return .Protocol
        case .J: return .Structure
        case .M: return .Class
        case .P: return .Structure
        case .S: return .Structure
        case .s: return .Structure
        case .T: return .Structure
        case .t: return .Structure
        }
    }
    
    var typeName: String {
        switch self {
        case .A: return "Actor"
        case .C: return "CheckedContinuation"
        case .c: return "UnsafeContinuation"
        case .E: return "CancellationError"
        case .e: return "UnownedSerialExecutor"
        case .F: return "Executor"
        case .f: return "SerialExecutor"
        case .G: return "TaskGroup"
        case .g: return "ThrowingTaskGroup"
        case .I: return "AsyncIteratorProtocol"
        case .i: return "AsyncSequence"
        case .J: return "UnownedJob"
        case .M: return "MainActor"
        case .P: return "TaskPriority"
        case .S: return "AsyncStream"
        case .s: return "AsyncThrowingStream"
        case .T: return "Task"
        case .t: return "UnsafeCurrentTask"
        }
    }
}

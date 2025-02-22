//
//  enum.swift
//  Demangling
//
//  Created by spacefrog on 2021/04/02.
//

import Foundation

struct FunctionSigSpecializationParamKind: Equatable {
    
    public let rawValue: UInt
    
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    init(kind: Kind) {
        self.rawValue = kind.rawValue
    }
    
    init(optionSet: OptionSet) {
        self.rawValue = optionSet.rawValue
    }
    
    init(kind: Kind, optionSet: OptionSet) {
        self.rawValue = kind.rawValue | optionSet.rawValue
    }
    
    // Option Flags use bits 0-5. This give us 6 bits implying 64 entries to
    // work with.
    enum Kind: UInt, CustomStringConvertible {
        case ConstantPropFunction = 0
        case ConstantPropGlobal = 1
        case ConstantPropInteger = 2
        case ConstantPropFloat = 3
        case ConstantPropString = 4
        case ClosureProp = 5
        case BoxToValue = 6
        case BoxToStack = 7
        
        var description: String {
            switch self {
            case .ConstantPropFunction:
                return "FunctionSigSpecializationParamKind.ConstantPropFunction"
            case .ConstantPropGlobal:
                return "FunctionSigSpecializationParamKind.ConstantPropGlobal"
            case .ConstantPropInteger:
                return "FunctionSigSpecializationParamKind.ConstantPropInteger"
            case .ConstantPropFloat:
                return "FunctionSigSpecializationParamKind.ConstantPropFloat"
            case .ConstantPropString:
                return "FunctionSigSpecializationParamKind.ConstantPropString"
            case .ClosureProp:
                return "FunctionSigSpecializationParamKind.ClosureProp"
            case .BoxToValue:
                return "FunctionSigSpecializationParamKind.BoxToValue"
            case .BoxToStack:
                return "FunctionSigSpecializationParamKind.BoxToStack"
            }
        }
        
        func createFunctionSigSpecializationParamKind() -> FunctionSigSpecializationParamKind {
            FunctionSigSpecializationParamKind(kind: self)
        }
    }
    // Option Set Flags use bits 6-31. This gives us 26 bits to use for option
    // flags.
    struct OptionSet: Swift.OptionSet, CustomStringConvertible {
        
        var rawValue: UInt
        
        fileprivate static let all: Self = [.Dead, .OwnedToGuaranteed, .SROA, .GuaranteedToOwned, .ExistentialToGeneric]
        
        static let Dead = Self(rawValue: 1 << 6)
        static let OwnedToGuaranteed = Self(rawValue: 1 << 7)
        static let SROA = Self(rawValue: 1 << 8)
        static let GuaranteedToOwned = Self(rawValue: 1 << 9)
        static let ExistentialToGeneric = Self(rawValue: 1 << 10)
        
        var description: String {
            var descriptions: [String] = []
            if self.contains(.Dead) {
                descriptions.append("Dead")
            }
            if self.contains(.OwnedToGuaranteed) {
                descriptions.append("OwnedToGuaranteed")
            }
            if self.contains(.SROA) {
                descriptions.append("SROA")
            }
            if self.contains(.GuaranteedToOwned) {
                descriptions.append("GuaranteedToOwned")
            }
            if self.contains(.ExistentialToGeneric) {
                descriptions.append("ExistentialToGeneric")
            }
            return "FunctionSigSpecializationParamKind.[" + descriptions.joined(separator: ", ") + "]"
        }
        
        func createFunctionSigSpecializationParamKind() -> FunctionSigSpecializationParamKind {
            .init(optionSet: self)
        }
    }
    
    func containKind(_ kind: Kind) -> Bool {
        self.kind == kind
    }
    
    func containOptions(_ members: OptionSet...) -> Bool {
        members.allSatisfy(optionSet.contains)
    }
    
    var kind: Kind? {
        guard optionSet.isEmpty else { return nil }
        return Kind(rawValue: rawValue)
    }
    
    var optionSet: OptionSet {
        guard rawValue > 7 else { return [] }
        return OptionSet(rawValue: rawValue)
    }
    
    var isValidOptionSet: Bool {
        !optionSet.intersection(OptionSet.all).isEmpty
    }
}

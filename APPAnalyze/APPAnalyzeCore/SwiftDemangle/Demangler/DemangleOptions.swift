//
//  DemangleOptions.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/26.
//

import Foundation

public struct DemangleOptions: OptionSet {
    
    static var hidingCurrentModule: String?
    var isClassify: Bool = false
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let synthesizeSugarOnTypes            = DemangleOptions(rawValue: 1)
    public static let qualifyEntities                   = DemangleOptions(rawValue: 1 << 1)
    public static let displayExtensionContexts          = DemangleOptions(rawValue: 1 << 2)
    public static let displayUnmangledSuffix            = DemangleOptions(rawValue: 1 << 3)
    public static let displayModuleNames                = DemangleOptions(rawValue: 1 << 4)
    public static let displayGenericSpecializations     = DemangleOptions(rawValue: 1 << 5)
    public static let displayProtocolConformances       = DemangleOptions(rawValue: 1 << 6)
    public static let displayWhereClauses               = DemangleOptions(rawValue: 1 << 7)
    public static let displayEntityTypes                = DemangleOptions(rawValue: 1 << 8)
    public static let displayLocalNameContexts          = DemangleOptions(rawValue: 1 << 9)
    public static let shortenPartialApply               = DemangleOptions(rawValue: 1 << 10)
    public static let shortenThunk                      = DemangleOptions(rawValue: 1 << 11)
    public static let shortenValueWitness               = DemangleOptions(rawValue: 1 << 12)
    public static let shortenArchetype                  = DemangleOptions(rawValue: 1 << 13)
    public static let showPrivateDiscriminators         = DemangleOptions(rawValue: 1 << 14)
    public static let showFunctionArgumentTypes         = DemangleOptions(rawValue: 1 << 15)
    public static let displayDebuggerGeneratedModule    = DemangleOptions(rawValue: 1 << 16)
    public static let displayStdlibModule               = DemangleOptions(rawValue: 1 << 17)
    public static let displayObjCModule                 = DemangleOptions(rawValue: 1 << 18)
    public static let printForTypeName                  = DemangleOptions(rawValue: 1 << 19)
    public static let showAsyncResumePartial            = DemangleOptions(rawValue: 1 << 20)
    
    public static let defaultOptions: DemangleOptions = [
        .synthesizeSugarOnTypes,
        .qualifyEntities,
        .displayExtensionContexts,
        .displayUnmangledSuffix,
        .displayModuleNames,
        .displayGenericSpecializations,
        .displayProtocolConformances,
        .displayWhereClauses,
        .displayEntityTypes,
        .displayLocalNameContexts,
        .showPrivateDiscriminators,
        .showFunctionArgumentTypes,
        .displayDebuggerGeneratedModule,
        .displayStdlibModule,
        .displayObjCModule,
        .showAsyncResumePartial,
    ]
    
    public static let simplifiedOptions: DemangleOptions = [
        .synthesizeSugarOnTypes, .qualifyEntities, .displayLocalNameContexts, shortenPartialApply, .shortenThunk, .shortenValueWitness, .shortenArchetype, .displayDebuggerGeneratedModule, .displayStdlibModule, .displayObjCModule, .showAsyncResumePartial
    ]
    
    func genericParameterName(depth: UInt64, index: UInt64) -> String {
        var name = ""
        var index = index
        repeat {
            // A(65) + index
            name.append("A" + UInt8(index % 26))
            index /= 26
        } while index > 0
        if depth > 0 {
            name.append(depth.description)
        }
      return name
    }
}

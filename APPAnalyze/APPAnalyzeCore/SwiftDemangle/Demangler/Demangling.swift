//
//  Demanglable.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/28.
//

import Foundation

protocol Demangling {
    var isSwiftSymbol: Bool { get }
    var isThunkSymbol: Bool { get }
    var isMangledName: Bool { get }
    var isObjCSymbol: Bool { get }
    var droppingSwiftManglingPrefix: String { get }
    
    func demangleSymbolAsNode() -> Node?
    func demangleSymbol() -> Node?
    func demangleOldSymbolAsNode() -> Node?
    func demangleSymbolAsString(with options: DemangleOptions) throws -> String
}

extension String: Demangling, Mangling {}
extension Substring: Demangling, Mangling {}

extension Demangling where Self: StringProtocol, Self: Mangling {
    
    internal var isSwiftSymbol: Bool {
        if isOldFunctionType(self) {
            return true
        } else {
            return manglingPrefixLength(from: self) != 0
        }
    }
    
    var isMangledName: Bool {
        manglingPrefixLength(from: self) > 0
    }
    
    var isObjCSymbol: Bool {
        let nameWithoutPrefix = droppingSwiftManglingPrefix
        return nameWithoutPrefix.hasPrefix("So") || nameWithoutPrefix.hasPrefix("SC")
    }
    
    internal var isThunkSymbol: Bool {
        let name = String(self)
        if name.isMangledName {
            let MangledName = name.strippingSuffix()
            // First do a quick check
            if (MangledName.hasSuffix("TA") ||  // partial application forwarder
                    MangledName.hasSuffix("Ta") ||  // ObjC partial application forwarder
                    MangledName.hasSuffix("To") ||  // swift-as-ObjC thunk
                    MangledName.hasSuffix("TO") ||  // ObjC-as-swift thunk
                    MangledName.hasSuffix("TR") ||  // reabstraction thunk helper function
                    MangledName.hasSuffix("Tr") ||  // reabstraction thunk
                    MangledName.hasSuffix("TW") ||  // protocol witness thunk
                    MangledName.hasSuffix("fC")) {  // allocating constructor
                
                // To avoid false positives, we need to fully demangle the symbol.
                guard let Nd = MangledName.demangleSymbol(), Nd.getKind() == .Global, Nd.numberOfChildren > 0 else { return false }
                
                switch Nd.firstChild.kind {
                case .ObjCAttribute, .NonObjCAttribute, .PartialApplyObjCForwarder, .PartialApplyForwarder, .ReabstractionThunkHelper, .ReabstractionThunk, .ProtocolWitness, .Allocator:
                    return true
                default:
                    break
                }
            }
            return false
        }
        
        if name.hasPrefix("_T") {
            // Old mangling.
            let Remaining = String(name.dropFirst(2))
            if (Remaining.hasPrefix("To") ||   // swift-as-ObjC thunk
                    Remaining.hasPrefix("TO") ||   // ObjC-as-swift thunk
                    Remaining.hasPrefix("PA_") ||  // partial application forwarder
                    Remaining.hasPrefix("PAo_")) { // ObjC partial application forwarder
                return true
            }
        }
        return false
    }
    
    var droppingSwiftManglingPrefix: String {
        String(self.dropFirst(manglingPrefixLength(from: self)))
    }
    
    internal func strippingSuffix() -> String {
        var name = String(self)
        guard name.isNotEmpty else { return name }
        if name.last?.isDigit ?? false {
            if let dotPos = name.range(of: ".") {
                name = String(name[name.startIndex..<dotPos.lowerBound])
            }
        }
        return name
    }
    
    internal func demangleSymbolAsNode() -> Node? {
        if isMangledName {
            return demangleSymbol()
        } else {
            return demangleOldSymbolAsNode()
        }
    }
    
    internal func demangleSymbol() -> Node? {
        let mangler = Demangler(String(self))
        return mangler.demangleSymbol()
    }
    
    func demangleOldSymbolAsNode() -> Node? {
        let mangler = OldDemangler(String(self))
        return mangler.demangleTopLevel()
    }
    
    internal func demangleSymbolAsString(with options: DemangleOptions) throws -> String {
        let root = demangleSymbolAsNode()
        var name = options.isClassify ? self.classified(root) : ""
        if let root = root {
            var printer = NodePrinter(options: options)
            if let nodeToString = try printer.printRoot(root).emptyToNil() {
                name += nodeToString
            } else {
                name = String(self)
            }
        } else {
            name += String(self)
        }
        return name
    }
    
    private func classified(_ node: Node?) -> String {
        var Classifications = ""
        if !self.isSwiftSymbol {
            Classifications.append("N")
        }
        if self.isThunkSymbol {
            if Classifications.isNotEmpty {
                Classifications.append(",")
            }
            Classifications.append("T:")
            Classifications += self.thunkTarget()
        } else {
            assert(self.thunkTarget().isEmpty)
        }
        if (node != nil && !self.hasSwiftCallingConvention()) {
            if Classifications.isNotEmpty {
                Classifications += ","
            }
            Classifications += "C"
        }
        if Classifications.isNotEmpty {
            return "{" + Classifications + "} "
        } else {
            return ""
        }
    }
    
    private func thunkTarget() -> String {
        let MangledName = String(self)
        if !MangledName.isThunkSymbol {
            return ""
        }
        
        if MangledName.isMangledName {
            // If the symbol has a suffix we cannot derive the target.
            if MangledName.strippingSuffix() != MangledName {
                return ""
            }
            
            // The targets of those thunks not derivable from the mangling.
            if (MangledName.hasSuffix("TR") ||
                    MangledName.hasSuffix("Tr") ||
                    MangledName.hasSuffix("TW") ) {
                return ""
            }
            
            if MangledName.hasSuffix("fC") {
                var target = MangledName
                target.removeLast()
                target.append("c")
                return target
            }
            
            return String(MangledName.dropLast(2))
        }
        // Old mangling.
        assert(MangledName.hasPrefix("_T"))
        let Remaining = String(MangledName.dropFirst(2))
        if Remaining.hasPrefix("PA_") {
            return String(Remaining.dropFirst(3))
        }
        if Remaining.hasPrefix("PAo_") {
            return String(Remaining.dropFirst(4))
        }
        assert(Remaining.hasPrefix("To") || Remaining.hasPrefix("TO"))
        return "_T" + String(Remaining.dropFirst(2))
    }
    
    func hasSwiftCallingConvention() -> Bool {
        guard let Global = self.demangleSymbolAsNode(), Global.kind == .Global, Global.numberOfChildren > 0 else { return false }
        
        let TopLevel = Global.firstChild
        switch TopLevel.kind {
        // Functions, which don't have the swift calling conventions:
        case .TypeMetadataAccessFunction, .ValueWitness, .ProtocolWitnessTableAccessor, .GenericProtocolWitnessTableInstantiationFunction, .LazyProtocolWitnessTableAccessor, .AssociatedTypeMetadataAccessor, .AssociatedTypeWitnessTableAccessor, .BaseWitnessTableAccessor, .ObjCAttribute:
            return false
        default:
            break
        }
        return true
    }
    
    internal func demangledModuleName() -> String? {
        var node = demangleSymbolAsNode()
        while let nd = node {
            switch nd.kind {
            case .Module:
                return nd.text
            case .TypeMangling, .Type:
                node = nd.firstChild
            case .Global:
                var newNode: Node?
                for child in nd.copyOfChildren {
                    if !child.kind.isFunctionAttr {
                        newNode = child
                        break
                    }
                }
                node = newNode
                break
            default:
                if nd.isSpecialized {
                    node = nd.unspecialized()
                    break
                }
                if nd.kind.isContext {
                    node = nd.getFirstChild()
                    break
                }
                return ""
            }
        }
        return ""
    }
    
}

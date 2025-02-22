//
//  OldDemangler.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/29.
//

import Foundation

class OldDemangler: Demanglerable {
    var mangled: Data
    let mangledOriginal: Data
    
    let numerics: [Character] = (0...9).map(\.description).map(Character.init)
    
    private(set) var substitutions: [Node] = []
    
    private(set) var printerName: String = ""
    
    required init(_ mangled: String) {
        self.mangled = mangled.data(using: .ascii) ?? Data()
        self.mangledOriginal = Data(self.mangled)
    }
    
    func demangleTopLevel() -> Node? {
        guard nextIf("_T") else { return nil }
        
        let topLevel: Node = Node(kind: .Global)
        
        // First demangle any specialization prefixes.
        if nextIf("TS") {
            repeat {
                if let specAttr = demangleSpecializedAttribute() {
                    topLevel.add(specAttr)
                } else {
                    return nil
                }
                
                // The Substitution header does not share state with the rest
                // of the mangling.
                substitutions.removeAll()
            } while nextIf("_TTS")
            
            // Then check that we have a global.
            guard nextIf("_T") else { return nil }
        } else if nextIf("To") {
            topLevel.add(.ObjCAttribute)
        } else if nextIf("TO") {
            topLevel.add(.NonObjCAttribute)
        } else if nextIf("TD") {
            topLevel.add(.DynamicAttribute)
        } else if nextIf("Td") {
            topLevel.add(.DirectMethodReferenceAttribute)
        } else if nextIf("TV") {
            topLevel.add(.VTableAttribute)
        }
        
        if let global = demangleGlobal() {
            topLevel.add(global)
        } else {
            return nil
        }
        
        // Add a suffix node if there's anything left unmangled.
        if (isNotEmpty) {
            topLevel.add(kind: .Suffix, text: self.text)
        }
        
        return topLevel
    }
    
    func demangleTypeName() -> Node? {
        demangleType()
    }
    
    func demangleDirectness() -> Node.Directness? {
        switch true {
        case nextIf("d"):
            return .direct
        case nextIf("i"):
            return .indirect
        default:
            return nil
        }
    }
    
    func demangleNatural<Number>(number: inout Number) -> Bool where Number: FixedWidthInteger {
        if isEmpty {
            return false
        }
        if let n = next()?.number(Number.self) {
            number = n
        } else {
            return false
        }
        while true {
            if isEmpty {
                return true
            }
            if let n = peek().number(Number.self) {
                number = Number(number.multipliedFullWidth(by: 10).low.advanced(by: Int(n)))
            } else {
                return true
            }
            next()
        }
    }
    
    func demangleBuiltinSize(number: inout UInt64) -> Bool {
        guard demangleNatural(number: &number) else { return false }
        return nextIf("_")
    }
    
    func demangleValueWitnessKind() -> Node.ValueWitnessKind? {
        if isEmpty {
            return nil
        }
        var codes: [Character] = [Character](repeating: "".character, count: 2)
        if let next = next() {
            codes[0] = next
        }
        if isEmpty {
            return nil
        }
        if let next = next() {
            codes[1] = next
        }
        let codeStr = codes.map(\.description).joined()
        return Node.ValueWitnessKind(code: codeStr)
    }
    
    func demangleGlobal() -> Node? {
        guard isNotEmpty else { return nil }
        
        // Type metadata.
        if nextIf("M") {
            if nextIf("P") {
                let pattern = Node(kind: .GenericTypeMetadataPattern)
                return demangleChildOrReturn(parent: pattern, kind: .Type)
            }
            if nextIf("a") {
                let accessor = Node(kind: .TypeMetadataAccessFunction)
                return demangleChildOrReturn(parent: accessor, kind: .Type)
            }
            if nextIf("L") {
                let cache = Node(kind: .TypeMetadataLazyCache)
                return demangleChildOrReturn(parent: cache, kind: .Type)
            }
            if nextIf("m") {
                let metaclass = Node(kind: .Metaclass)
                return demangleChildOrReturn(parent: metaclass, kind: .Type)
            }
            if nextIf("n") {
                let nominalType = Node(kind:. NominalTypeDescriptor)
                return demangleChildOrReturn(parent: nominalType, kind: .Type)
            }
            if nextIf("f") {
                let metadata = Node(kind: .FullTypeMetadata)
                return demangleChildOrReturn(parent: metadata, kind: .Type)
            }
            if nextIf("p") {
                let metadata = Node(kind: .ProtocolDescriptor)
                if let protocolName = demangleProtocolName() {
                    metadata.add(protocolName)
                }
                return metadata
            }
            
            let metadata = Node(kind: .TypeMetadata)
            return demangleChildOrReturn(parent: metadata, kind: .Type)
        }
        
        // Partial application thunks.
        if nextIf("PA") {
            let kind: Node.Kind
            if nextIf("o") {
                kind = .PartialApplyObjCForwarder
            } else {
                kind = .PartialApplyForwarder
            }
            let forwarder = Node(kind: kind)
            if nextIf("__T") {
                return demangleChildOrReturn(parent: forwarder, kind: .Global)
            }
            return forwarder
        }
        
        // Top-level types, for various consumers.
        if nextIf("t") {
            let type = Node(kind: .TypeMangling)
            return demangleChildOrReturn(parent: type, kind: .Type)
        }
        
        // Value witnesses.
        if nextIf("w") {
            guard let w = demangleValueWitnessKind() else { return nil }
            let witness = Node(kind: .ValueWitness)
            let idx = Node(kind: .Index, payload: .valueWitnessKind(w))
            witness.add(idx)
            return demangleChildOrReturn(parent: witness, kind: .Type)
        }
        
        // Offsets, value witness tables, and protocol witnesses.
        if nextIf("W") {
            if nextIf("V") {
                let witnessTable = Node(kind: .ValueWitnessTable)
                return demangleChildOrReturn(parent: witnessTable, kind: .Type)
            }
            if nextIf("v") {
                let _fieldOffset = Node(kind: .FieldOffset)
                guard let fieldOffset = demangleChildAsNodeOrReturn(parent: _fieldOffset, kind: .Directness) else { return nil }
                if let entity = demangleEntity() {
                    fieldOffset.add(entity)
                } else {
                    return nil
                }
                return fieldOffset
            }
            if nextIf("P") {
                let witnessTable = Node(kind: .ProtocolWitnessTable)
                return demangleChildOrReturn(parent: witnessTable, kind: .ProtocolConformance)
            }
            if nextIf("G") {
                let witnessTable = Node(kind: .GenericProtocolWitnessTable)
                return demangleChildOrReturn(parent: witnessTable, kind: .ProtocolConformance)
            }
            if nextIf("I") {
                let witnessTable = Node(kind: .GenericProtocolWitnessTableInstantiationFunction)
                return demangleChildOrReturn(parent: witnessTable, kind: .ProtocolConformance)
            }
            if nextIf("l") {
                let _accessor = Node(kind: .LazyProtocolWitnessTableAccessor)
                guard let accessor = demangleChildOrReturn(parent: _accessor, kind: .Type) else { return nil }
                return demangleChildOrReturn(parent: accessor, kind: .ProtocolConformance)
            }
            if nextIf("L") {
                let _accessor = Node(kind: .LazyProtocolWitnessTableCacheVariable)
                guard let accessor = demangleChildOrReturn(parent: _accessor, kind: .Type) else { return nil }
                return demangleChildOrReturn(parent: accessor, kind: .ProtocolConformance)
            }
            if nextIf("a") {
                let tableTemplate = Node(kind: .ProtocolWitnessTableAccessor)
                return demangleChildOrReturn(parent: tableTemplate, kind: .ProtocolConformance)
            }
            if nextIf("t") {
                let _accessor = Node(kind: .AssociatedTypeMetadataAccessor)
                guard let accessor = demangleChildOrReturn(parent: _accessor, kind: .ProtocolConformance) else { return nil }
                if let child = demangleDeclName() {
                    accessor.add(child)
                } else {
                    return nil
                }
                return accessor
            }
            if nextIf("T") {
                let _accessor = Node(kind: .AssociatedTypeWitnessTableAccessor)
                guard let accessor = demangleChildOrReturn(parent: _accessor, kind: .ProtocolConformance) else { return nil }
                if let child = demangleDeclName() {
                    accessor.add(child)
                } else {
                    return nil
                }
                if let child = demangleProtocolName() {
                    accessor.add(child)
                } else {
                    return nil
                }
                return accessor
            }
            return nil
        }
        
        // Other thunks.
        if nextIf("T") {
            if nextIf("R") {
                var thunk = Node(kind: .ReabstractionThunkHelper)
                guard demangleReabstractSignature(signature: &thunk) else { return nil }
                return thunk
            }
            if nextIf("r") {
                var thunk = Node(kind: .ReabstractionThunk)
                guard demangleReabstractSignature(signature: &thunk) else { return nil }
                return thunk
            }
            if nextIf("W") {
                let _thunk = Node(kind: .ProtocolWitness)
                guard let thunk = demangleChildOrReturn(parent: _thunk, kind: .ProtocolConformance) else { return nil }
                // The entity is mangled in its own generic context.
                guard let entity = demangleEntity() else { return nil }
                thunk.add(entity)
                return thunk
            }
            return nil
        }
        return demangleEntity()
    }
    
    func demangleGenericSpecialization(_ specialization: Node) -> Node? {
        let specialization = specialization
        while !nextIf("_") {
            // Otherwise, we have another parameter. Demangle the type.
            let param = Node(kind: .GenericSpecializationParam)
            if let type = demangleType() {
                param.add(type)
            } else {
                return nil
            }
            
            // Then parse any conformances until we find an underscore. Pop off the
            // underscore since it serves as the end of our mangling list.
            while !nextIf("_") {
                if let protoConfo = demangleProtocolConformance() {
                    param.add(protoConfo)
                } else {
                    return nil
                }
            }
            
            // Add the parameter to our specialization list.
            specialization.add(param)
        }
        
        return specialization
    }
    
    func demangleFuncSigSpecializationConstantProp(parent: inout Node) -> Bool {
        // Then figure out what was actually constant propagated. First check if
        // we have a function.
        
        if nextIf("fr") {
            // Demangle the identifier
            guard let name = demangleIdentifier(), nextIf("_") else { return false }
            parent.addFunctionSigSpecializationParamKind(kind: .ConstantPropFunction, texts: name.text)
            return true
        }
        
        if nextIf("g") {
            guard let name = demangleIdentifier(), nextIf("_") else { return false }
            parent.addFunctionSigSpecializationParamKind(kind: .ConstantPropGlobal, texts: name.text)
            return true
        }
        
        if nextIf("i") {
            guard let str = readUntil("_").emptyToNil(), nextIf("_") else { return false }
            parent.addFunctionSigSpecializationParamKind(kind: .ConstantPropInteger, texts: str)
            return true
        }
        
        if nextIf("fl") {
            guard let str = readUntil("_").emptyToNil(), nextIf("_") else { return false }
            parent.addFunctionSigSpecializationParamKind(kind: .ConstantPropFloat, texts: str)
            return true
        }
        
        if nextIf("s") {
            // Skip: 'e' encoding 'v' str. encoding is a 0 or 1 and str is a string of
            // length less than or equal to 32. We do not specialize strings with a
            // length greater than 32.
            guard nextIf("e") else { return false }
            let encoding = peek()
            guard encoding == "0" || encoding == "1" else { return false }
            let encodingStr: String
            if encoding == "0" {
                encodingStr = "u8"
            } else {
                encodingStr = "u16"
            }
            advanceOffset(1)
            
            guard nextIf("v") else { return false }
            guard let str = demangleIdentifier(), nextIf("_") else { return false }
            parent.addFunctionSigSpecializationParamKind(kind: .ConstantPropString, texts: encodingStr, str.text)
            return true
        }
        
        // Unknown constant prop specialization
        return false;
    }
    
    func demangleFuncSigSpecializationClosureProp(parent: inout Node) -> Bool {
        // We don't actually demangle the function or types for now. But we do want
        // to signal that we specialized a closure.
        guard let name = demangleIdentifier() else { return false }
        
        parent.addFunctionSigSpecializationParamKind(kind: .ClosureProp, texts: name.text)
        
        // Then demangle types until we fail.
        while peek() != "_", let type = demangleType() {
            parent.add(type)
        }
        
        // Eat last '_'
        guard nextIf("_") else { return false }
        
        return true
    }
    
    func demangleFunctionSignatureSpecialization(_ specialization: Node) -> Node? {
        let specialization = specialization
        // Until we hit the last '_' in our specialization info...
        while !nextIf("_") {
            // Create the parameter.
            var param = Node(kind: .FunctionSignatureSpecializationParam)
            
            // First handle options.
            if nextIf("n_") {
                // Leave the parameter empty.
            } else if nextIf("cp") {
                guard demangleFuncSigSpecializationConstantProp(parent: &param) else { return nil }
            } else if nextIf("cl") {
                guard demangleFuncSigSpecializationClosureProp(parent: &param) else { return nil }
            } else if nextIf("i_") {
                param.add(Node(kind: .FunctionSignatureSpecializationParamKind, functionParamKind: .BoxToValue))
            } else if nextIf("k_") {
                param.add(Node(kind: .FunctionSignatureSpecializationParamKind, functionParamKind: .BoxToStack))
            } else {
                // Otherwise handle option sets.
                var value: FunctionSigSpecializationParamKind.OptionSet = .init()
                if nextIf("d") {
                    value.insert(.Dead)
                }
                
                if nextIf("g") {
                    value.insert(.OwnedToGuaranteed)
                }
                
                if nextIf("o") {
                    value.insert(.GuaranteedToOwned)
                }
                
                if nextIf("s") {
                    value.insert(.SROA)
                }
                
                guard nextIf("_") else { return nil }
                
                guard !value.isEmpty else { return nil }

                param.add(Node(kind: .FunctionSignatureSpecializationParamKind, functionParamOption: value))
            }
            
            specialization.add(param)
        }
        
        return specialization
    }
    
    
    func demangleSpecializedAttribute() -> Node? {
        var isNotReAbstracted = false
        if nextIf("g") || isNotReAbstracted.changing(nextIf(("r"))) {
            let spec = Node(kind: isNotReAbstracted ? .GenericSpecializationNotReAbstracted : .GenericSpecialization)
            
            // Create a node if the specialization is serialized.
            if nextIf("q") {
                spec.add(.IsSerialized)
            }
            
            // Create a node for the pass id.
            spec.add(Node(kind: .SpecializationPassID, index: next()?.number(UInt64.self) ?? 0))
            
            // And then mangle the generic specialization.
            return demangleGenericSpecialization(spec)
        }
        if nextIf("f") {
            let spec = Node(kind: .FunctionSignatureSpecialization)
            
            // Create a node if the specialization is serialized.
            if nextIf("q") {
                spec.add(.IsSerialized)
            }
            
            // Add the pass id.
            spec.add(Node(kind: .SpecializationPassID, index: next()?.number(UInt64.self) ?? 0))
            
            // Then perform the function signature specialization.
            return demangleFunctionSignatureSpecialization(spec)
        }
        
        // We don't know how to handle this specialization.
        return nil
    }
    
    func demangleDeclName() -> Node? {
        // decl-name ::= local-decl-name
        // local-decl-name ::= 'L' index identifier
        if nextIf("L") {
            guard let discriminator = demangleIndexAsNode() else { return nil }
            guard let name = demangleIdentifier() else { return nil }
            
            let localName = Node(kind: .LocalDeclName)
            localName.add(discriminator)
            localName.add(name)
            return localName
        } else if nextIf("P") {
            guard let discriminator = demangleIdentifier() else { return nil }
            guard let name = demangleIdentifier() else { return nil }
            
            let privateName = Node(kind: .PrivateDeclName)
            privateName.add(discriminator)
            privateName.add(name)
            return privateName
        }
        
        // decl-name ::= identifier
        return demangleIdentifier();
    }
    
    func demangleIdentifier(kind _kind: Node.Kind? = nil) -> Node? {
        if mangled.isEmpty {
            return nil
        }
        
        let isPunycoded = nextIf("X")
        
        func decode(_ text: String) -> String {
            guard isPunycoded else { return text }
            return Punycode(string: text).decode() ?? ""
        }
        
        var _kind = _kind
        
        var isOperator = false
        if nextIf("o") {
            isOperator = true
            // Operator identifiers aren't valid in the contexts that are
            // building more specific identifiers.
            guard _kind == nil else { return nil }
            
            guard let op_mode = next() else { return nil }
            switch op_mode {
            case "p":
                _kind = .PrefixOperator
            case "P":
                _kind = .PostfixOperator
            case "i":
                _kind = .InfixOperator
            default:
                return nil
            }
        }
        
        let kind: Node.Kind = _kind ?? .Identifier
        
        var length: UInt64 = 0
        guard demangleNatural(number: &length) else { return nil }
        guard hasAtLeast(length) else { return nil }
        
        var identifier = slice(Int(length))
        advanceOffset(Int(length))
        
        // Decode Unicode identifiers.
        identifier = decode(identifier)
        if identifier.isEmpty {
            return nil
        }
        
        // Decode operator names.
        var opDecodeBuffer: String = ""
        if isOperator {
            // abcdefghijklmnopqrstuvwxyz
            let op_char_table: [Character] = "& @/= >    <*!|+?%-~   ^ .".map({$0})
            for c in identifier {
                guard let asciiValue = c.asciiValue else {
                    opDecodeBuffer.append(c)
                    continue
                }
                
                guard c >= "a", c <= "z" else { return nil }
                let o = op_char_table[Int(asciiValue - "a".first!.asciiValue!)]
                guard o != " " else { return nil }
                opDecodeBuffer.append(o)
            }
            identifier = opDecodeBuffer
        }
        
        return Node(kind: kind, text: identifier)
    }
    
    func demangleIndex(_ number: inout UInt64) -> Bool {
        if nextIf("_") {
            number = 0
            return true
        }
        if demangleNatural(number: &number) {
            if !nextIf("_") {
                return false
            }
            number += 1
            return true
        } else {
            return false
        }
    }
    
    /// Demangle an <index> and package it as a node of some kind.
    func demangleIndexAsNode(kind: Node.Kind = .Number) -> Node? {
        var index: UInt64 = 0
        guard demangleIndex(&index) else { return nil }
        return Node(kind: kind, index: index)
    }

    func createSwiftType(typeKind: Node.Kind, name: String) -> Node {
        let type = Node(kind: typeKind)
        type.add(Node(kind: .Module, text: .STDLIB_NAME))
        type.add(Node(kind: .Identifier, text: name))
        return type
    }
    
    func demangleSubstitutionIndex() -> Node? {
        if mangled.isEmpty {
            return nil
        }
        if nextIf("o") {
            return .init(kind: .Module, text: .MANGLING_MODULE_OBJC)
        }
        if nextIf("C") {
            return .init(kind: .Module, text: .MANGLING_MODULE_CLANG_IMPORTER)
        }
        if nextIf("a") {
          return createSwiftType(typeKind: .Structure, name: "Array")
        }
        if nextIf("b") {
          return createSwiftType(typeKind: .Structure, name: "Bool")
        }
        if nextIf("c") {
          return createSwiftType(typeKind: .Structure, name: "UnicodeScalar")
        }
        if nextIf("d") {
          return createSwiftType(typeKind: .Structure, name: "Double")
        }
        if nextIf("f") {
          return createSwiftType(typeKind: .Structure, name: "Float")
        }
        if nextIf("i") {
          return createSwiftType(typeKind: .Structure, name: "Int")
        }
        if nextIf("V") {
          return createSwiftType(typeKind: .Structure, name: "UnsafeRawPointer")
        }
        if nextIf("v") {
          return createSwiftType(typeKind: .Structure, name: "UnsafeMutableRawPointer")
        }
        if nextIf("P") {
          return createSwiftType(typeKind: .Structure, name: "UnsafePointer")
        }
        if nextIf("p") {
          return createSwiftType(typeKind: .Structure, name: "UnsafeMutablePointer")
        }
        if nextIf("q") {
          return createSwiftType(typeKind: .Enum, name: "Optional")
        }
        if nextIf("Q") {
          return createSwiftType(typeKind: .Enum, name: "ImplicitlyUnwrappedOptional")
        }
        if nextIf("R") {
          return createSwiftType(typeKind: .Structure, name: "UnsafeBufferPointer")
        }
        if nextIf("r") {
          return createSwiftType(typeKind: .Structure, name: "UnsafeMutableBufferPointer")
        }
        if nextIf("S") {
          return createSwiftType(typeKind: .Structure, name: "String")
        }
        if nextIf("u") {
          return createSwiftType(typeKind: .Structure, name: "UInt")
        }
        var index_sub: UInt64 = 0
        guard demangleIndex(&index_sub) else { return nil }
        guard index_sub < substitutions.count else { return nil }
        return substitutions[Int(index_sub)]
    }
    
    func demangleModule() -> Node? {
        if nextIf("s") {
            return Node(kind: .Module, text: .STDLIB_NAME)
        }
        if nextIf("S") {
            guard let module = demangleSubstitutionIndex() else { return nil }
            guard module.kind != .Module else { return nil }
            return module
        }
        
        guard let module = demangleIdentifier(kind: .Module) else { return nil }
        substitutions.append(module)
        return module
    }
    
    func demangleDeclarationName(kind: Node.Kind) -> Node? {
        guard let context = demangleContext() else {
            return nil
        }
        guard let name = demangleDeclName() else {
            return nil
        }
        let decl = Node(kind: kind)
        decl.add(context)
        decl.add(name)
        substitutions.append(decl)
        return decl
    }
    
    func demangleProtocolName() -> Node? {
        guard let proto = demangleProtocolNameImpl() else { return nil }
        
        let type = Node(kind: .Type)
        type.add(proto)
        return type
    }
    
    func demangleProtocolNameGivenContext(_ context: Node) -> Node? {
        guard let name = demangleDeclName() else { return nil }
        
        let proto = Node(kind: .Protocol)
        proto.add(context)
        proto.add(name)
        substitutions.append(proto)
        return proto
    }
    
    func demangleProtocolNameImpl() -> Node? {
        // There's an ambiguity in <protocol> between a substitution of
        // the protocol and a substitution of the protocol's context, so
        // we have to duplicate some of the logic from
        // demangleDeclarationName.
        if nextIf("S") {
            guard let sub = demangleSubstitutionIndex() else { return nil }
            if sub.kind == .Protocol {
                return sub
            }
            
            guard sub.kind == .Module else { return nil }
            
            return demangleProtocolNameGivenContext(sub)
        }
        
        if nextIf("s") {
            let stdlib = Node(kind: .Module, text: .STDLIB_NAME)
            return demangleProtocolNameGivenContext(stdlib)
        }
        
        return demangleDeclarationName(kind: .Protocol)
    }
    
    func demangleNominalType() -> Node? {
        if nextIf("S") {
            return demangleSubstitutionIndex()
        }
        if nextIf("V") {
            return demangleDeclarationName(kind: .Structure)
        }
        if nextIf("O") {
            return demangleDeclarationName(kind: .Enum)
        }
        if nextIf("C") {
            return demangleDeclarationName(kind: .Class)
        }
        if nextIf("P") {
            return demangleDeclarationName(kind: .Protocol)
        }
        return nil
    }
    
    func demangleBoundGenericArgs(nominalType: Node) -> Node? {
        var nominalType = nominalType
        // Generic arguments for the outermost type come first.
        guard var parentOrModule = nominalType.copyOfChildren.first else { return nil }

        if ![Node.Kind.Module, .Function, .Extension].contains(parentOrModule.kind) {
            guard let node = demangleBoundGenericArgs(nominalType: parentOrModule) else { return nil }
            parentOrModule = node
            let result = Node(kind: nominalType.kind)
            result.add(parentOrModule)
            result.add(nominalType.children(1))
            nominalType = result
        }
       
        let args = Node(kind: .TypeList)
        while !nextIf("_") {
            guard let type = demangleType() else { return nil }
            args.add(type)
            guard isNotEmpty else { return nil }
        }
        
        // If there were no arguments at this level there is nothing left
        // to do.
        if args.copyOfChildren.isEmpty {
            return nominalType
        }
        
        // Otherwise, build a bound generic type node from the unbound
        // type and arguments.
        let unboundType = Node(kind: .Type)
        unboundType.add(nominalType)
        
        let kind: Node.Kind
        switch nominalType.kind { // look through Type node
        case .Class:
            kind = .BoundGenericClass
        case .Structure:
            kind = .BoundGenericStructure
        case .Enum:
            kind = .BoundGenericEnum
        default:
            return nil
        }
        let result = Node(kind: kind)
        result.add(unboundType)
        result.add(args)
        return result
    }
    
    func demangleBoundGenericType() -> Node? {
        // bound-generic-type ::= 'G' nominal-type (args+ '_')+
        //
        // Each level of nominal type nesting has its own list of arguments.
        guard let nominalType = demangleNominalType() else { return nil }
        return demangleBoundGenericArgs(nominalType: nominalType)
    }
    
    func demangleContext() -> Node? {
      // context ::= module
      // context ::= entity
      // context ::= 'E' module context (extension defined in a different module)
      // context ::= 'e' module context generic-signature (constrained extension)
        guard isNotEmpty else { return nil }
        if nextIf("E") {
            guard let def_module = demangleModule() else { return nil }
            guard let type = demangleContext() else { return nil }
            let ext = Node(kind: .Extension)
            ext.add(def_module)
            ext.add(type)
            return ext
        }
        if nextIf("e") {
            guard let def_module = demangleModule() else { return nil }
            // The generic context is currently re-specified by the type mangling.
            // If we ever remove 'self' from manglings, we should stop resetting the
            // context here.
            guard let sig = demangleGenericSignature() else { return nil }
            guard let type = demangleContext() else { return nil }
            let ext = Node(kind: .Extension)
            ext.add(def_module)
            ext.add(type)
            ext.add(sig)
            return ext
        }
        if nextIf("S") {
            return demangleSubstitutionIndex()
        }
        if nextIf("s") {
            return Node(kind: .Module, text: .STDLIB_NAME)
        }
        if nextIf("G") {
            return demangleBoundGenericType()
        }
        if isStartOfEntity(peek()) {
            return demangleEntity()
        } else {
            return demangleModule()
        }
    }
    
    func demangleProtocolList() -> Node? {
        let proto_list = Node(kind: .ProtocolList)
        let type_list = Node(kind: .TypeList)
        while !nextIf("_") {
            guard let proto = demangleProtocolName() else { return nil }
            type_list.add(proto)
        }
        proto_list.add(type_list)
        return proto_list
    }
    
    func demangleProtocolConformance() -> Node? {
        guard let type = demangleType() else { return nil }
        guard let protocolName = demangleProtocolName() else { return nil }
        guard let context = demangleContext() else { return nil }
        let protocolConformance = Node(kind: .ProtocolConformance)
        protocolConformance.add(type)
        protocolConformance.add(protocolName)
        protocolConformance.add(context)
        return protocolConformance
    }
    
    // entity ::= entity-kind context entity-name
    // entity ::= nominal-type
    func demangleEntity() -> Node? {
        // static?
        let isStatic = nextIf("Z")
        
        // entity-kind
        let entityBasicKind: Node.Kind
        if nextIf("F") {
            entityBasicKind = .Function
        } else if nextIf("v") {
            entityBasicKind = .Variable
        } else if nextIf("I") {
            entityBasicKind = .Initializer
        } else if nextIf("i") {
            entityBasicKind = .Subscript
        } else {
            return demangleNominalType()
        }
        
        guard let context = demangleContext() else { return nil }
        
        // entity-name
        let entityKind: Node.Kind
        var hasType = true
        // Wrap the enclosed entity in a variable or subscript node
        var wrapEntity = false
        var name: Node?
        if nextIf("D") {
            entityKind = .Deallocator
            hasType = false
        } else if nextIf("d") {
            entityKind = .Destructor
            hasType = false
        } else if nextIf("e") {
            entityKind = .IVarInitializer
            hasType = false
        } else if nextIf("E") {
            entityKind = .IVarDestroyer
            hasType = false
        } else if nextIf("C") {
            entityKind = .Allocator
        } else if nextIf("c") {
            entityKind = .Constructor
        } else if nextIf("a") {
            wrapEntity = true
            if nextIf("O") {
                entityKind = .OwningMutableAddressor
            } else if nextIf("o") {
                entityKind = .NativeOwningMutableAddressor
            } else if nextIf("p") {
                entityKind = .NativePinningMutableAddressor
            } else if nextIf("u") {
                entityKind = .UnsafeMutableAddressor
            } else {
                return nil
            }
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("l") {
            wrapEntity = true;
            if nextIf("O") {
                entityKind = .OwningAddressor
            } else if nextIf("o") {
                entityKind = .NativeOwningAddressor
            } else if nextIf("p") {
                entityKind = .NativePinningAddressor
            } else if nextIf("u") {
                entityKind = .UnsafeAddressor
            } else {
                return nil
            }
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("g") {
            wrapEntity = true
            entityKind = .Getter
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("G") {
            wrapEntity = true;
            entityKind = .GlobalGetter
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("s") {
            wrapEntity = true;
            entityKind = .Setter
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("m") {
            wrapEntity = true;
            entityKind = .MaterializeForSet
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("w") {
            wrapEntity = true;
            entityKind = .WillSet
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("W") {
            wrapEntity = true;
            entityKind = .DidSet
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("r") {
            wrapEntity = true;
            entityKind = .ReadAccessor
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("M") {
            wrapEntity = true;
            entityKind = .ModifyAccessor
            guard let node = demangleDeclName() else { return nil }
            name = node
        } else if nextIf("U") {
            entityKind = .ExplicitClosure
            guard let node = demangleIndexAsNode() else { return nil }
            name = node
        } else if nextIf("u") {
            entityKind = .ImplicitClosure
            guard let node = demangleIndexAsNode() else { return nil }
            name = node
        } else if (entityBasicKind == .Initializer) {
            if nextIf("A") { // entity-name ::= 'A' index
                entityKind = .DefaultArgumentInitializer
                guard let node = demangleIndexAsNode() else { return nil }
                name = node
            } else if nextIf("i") { // entity-name ::= 'i'
                entityKind = .Initializer
            } else {
                return nil
            }
            hasType = false
        } else {
            entityKind = entityBasicKind;
            guard let node = demangleDeclName() else { return nil }
            name = node
        }
        
        let entity = Node(kind: entityKind)
        if wrapEntity {
            // Create a subscript or variable node and make it the accessor's child
            var wrappedEntity: Node
            var isSubscript = false
            
            // Rewrite the subscript's name to match the new mangling scheme
            switch name?.kind {
            case .Identifier:
                if name?.text == "subscript" {
                    isSubscript = true;
                    // Subscripts have no 'subscript' identifier name
                    name = nil
                }
            case .PrivateDeclName: // identifier file-discriminator?
                if name.map(\.numberOfChildren).or(0) > 1, name?.children(1).text == "subscript" {
                    isSubscript = true
                    
                    let discriminator = name?.children(0)
                    
                    // Create new PrivateDeclName with no 'subscript' identifier child
                    name = .init(kind: .PrivateDeclName)
                    name?.add(discriminator)
                }
            default:
                break
            }
            
            // Create wrapped entity node
            if isSubscript {
                wrappedEntity = Node(kind: .Subscript)
            } else {
                wrappedEntity = Node(kind: .Variable)
            }
            wrappedEntity.add(context)
            
            // Variables mangle their name before their type
            if !isSubscript {
                wrappedEntity.add(name)
            }
            
            if hasType {
                guard let type = demangleType() else { return nil }
                wrappedEntity.add(type)
            }
            
            // Subscripts mangle their file-discriminator after the type
            if isSubscript, let name = name {
                wrappedEntity.add(name)
            }
            
            entity.add(wrappedEntity)
        } else {
            entity.add(context)
            
            if let name = name {
                entity.add(name)
            }
            
            if hasType {
                guard let type = demangleType() else { return nil }
                entity.add(type)
            }
        }
        
        if isStatic {
            let staticNode = Node(kind: .Static)
            staticNode.add(entity)
            return staticNode
        }
        
        return entity
    }
    
    func getDependentGenericParamType(depth: UInt64, index: UInt64) -> Node? {
        self.printerName = NodePrinter(options: .defaultOptions).genericParameterName(depth: depth, index: index)
        let paramTy = Node(kind: .DependentGenericParamType)
        paramTy.add(kind: .Index, payload: .index(depth))
        paramTy.add(kind: .Index, payload: .index(index))
        return paramTy
    }
    
    func demangleGenericParamIndex() -> Node? {
        var depth: UInt64 = 0, index: UInt64 = 0
        
        if nextIf("d") {
            guard demangleIndex(&depth) else { return nil }
            depth += 1
            guard demangleIndex(&index) else { return nil }
        } else if nextIf("x") {
            depth = 0
            index = 0
        } else {
            guard demangleIndex(&index) else { return nil }
            depth = 0
            index += 1
        }
        return getDependentGenericParamType(depth: depth, index: index)
    }
    
    func demangleDependentMemberTypeName(base: Node) -> Node? {
        assert(base.kind == .Type, "base should be a type")
        var assocTy: Node?
        
        if nextIf("S") {
            assocTy = demangleSubstitutionIndex()
            if assocTy == nil {
                return nil
            }
            if assocTy?.kind != .DependentAssociatedTypeRef {
                return nil
            }
        } else {
            var protocolNode: Node?
            if nextIf("P") {
                protocolNode = demangleProtocolName()
                if protocolNode == nil {
                    return nil
                }
            }
            
            // TODO: If the protocol name was elided from the assoc type mangling,
            // we could try to fish it out of the generic signature constraints on the
            // base.
            guard let id = demangleIdentifier() else { return nil }
            assocTy = Node(kind: .DependentAssociatedTypeRef)
            if assocTy == nil {
                return nil
            }
            assocTy?.add(id)
            if let protocolNode = protocolNode {
                assocTy?.add(protocolNode)
            }
            
            if let assocTy = assocTy {
                substitutions.append(assocTy)
            }
        }
        
        let depTy = Node(kind: .DependentMemberType)
        depTy.add(base)
        if let assocTy = assocTy {
            depTy.add(assocTy)
        }
        return depTy
    }
    
    func demangleAssociatedTypeSimple() -> Node? {
        // Demangle the base type.
        guard let base = demangleGenericParamIndex() else { return nil }
        
        // Demangle the associated type name.
        let type = Node(kind: .Type)
        type.add(base)
        return demangleDependentMemberTypeName(base: type)
    }
    
    func demangleAssociatedTypeCompound() -> Node? {
        // Demangle the base type.
        var base = demangleGenericParamIndex()
        guard base.hasValue else { return nil }
        
        // Demangle the associated type chain.
        while !nextIf("_") {
            let nodeType = Node(kind: .Type)
            nodeType.add(base)
            
            base = demangleDependentMemberTypeName(base: nodeType)
            guard base.hasValue else { return nil }
        }
        
        return base
    }
    
    func demangleDependentType() -> Node? {
        guard isNotEmpty else { return nil }

        // A dependent member type begins with a non-index, non-'d' character.
        let c = peek()
        if c != "d", c != "_", !c.isDigit {
            guard let baseType = demangleType() else { return nil }
            return demangleDependentMemberTypeName(base: baseType)
        }
      
      // Otherwise, we have a generic parameter.
      return demangleGenericParamIndex()
    }
    
    func demangleConstrainedTypeImpl() -> Node? {
        // The constrained type can only be a generic parameter or an associated
        // type thereof. The 'q' introducer is thus left off of generic params.
        if nextIf("w") {
            return demangleAssociatedTypeSimple()
        }
        if nextIf("W") {
            return demangleAssociatedTypeCompound()
        }
        return demangleGenericParamIndex()
    }
    
    func demangleConstrainedType() -> Node? {
        guard let type = demangleConstrainedTypeImpl() else { return nil }
        let constrainedType = Node(kind: .Type)
        constrainedType.add(type)
        return constrainedType
    }
    
    func demangleGenericSignature(isPseudogeneric: Bool = false) -> Node? {
        let sig = Node(kind: isPseudogeneric ? .DependentPseudogenericSignature : .DependentGenericSignature)
        // First read in the parameter counts at each depth.
        var count = UInt64.max
        
        func addCount(sig: Node, count: UInt64) {
            sig.add(.init(kind: .DependentGenericParamCount, payload: .index(count)))
        }
        
        while peek() != "R", peek() != "r" {
            if nextIf("z") {
                count = 0
            } else if demangleIndex(&count) {
                count += 1
            } else {
                return nil
            }
            addCount(sig: sig, count: count)
        }
        
        // No mangled parameters means we have exactly one.
        if count == .max {
            count = 1
            addCount(sig: sig, count: count)
        }
        
        // Next read in the generic requirements, if any.
        if nextIf("r") {
            return sig
        }
        
        if !nextIf("R") {
            return nil
        }
        
        while !nextIf("r") {
            guard let reqt = demangleGenericRequirement() else { return nil }
            sig.add(reqt)
        }
        
        return sig
    }
    
    func demangleMetatypeRepresentation() -> Node? {
        if nextIf("t") {
            return Node(kind: .MetatypeRepresentation, text: "@thin")
        }

        if nextIf("T") {
            return Node(kind: .MetatypeRepresentation, text: "@thick")
        }

        if nextIf("o") {
            return Node(kind: .MetatypeRepresentation, text: "@objc_metatype")
        }

        // Unknown metatype representation
        return nil
    }
    
    func demangleGenericRequirement() -> Node? {
        guard let constrainedType = demangleConstrainedType() else { return nil }
        if nextIf("z") {
            guard let second = demangleType() else { return nil }
            let reqt = Node(kind: .DependentGenericSameTypeRequirement)
            reqt.add(constrainedType)
            reqt.add(second)
            return reqt
        }
        
        if nextIf("l") {
            let name: String
            let kind: Node.Kind
            var size = UInt64.max
            var alignment = UInt64.max
            if nextIf("U") {
                kind = .Identifier
                name = "U"
            } else if nextIf("R") {
                kind = .Identifier
                name = "R"
            } else if nextIf("N") {
                kind = .Identifier
                name = "N"
            } else if nextIf("T") {
                kind = .Identifier
                name = "T"
            } else if nextIf("E") {
                kind = .Identifier
                guard demangleNatural(number: &size) else { return nil }
                guard nextIf("_") else { return nil }
                guard demangleNatural(number: &alignment) else { return nil }
                name = "E"
            } else if nextIf("e") {
                kind = .Identifier
                guard demangleNatural(number: &size) else { return nil }
                name = "e"
            } else if nextIf("M") {
                kind = .Identifier
                guard demangleNatural(number: &size) else { return nil }
                guard nextIf("_") else { return nil }
                guard demangleNatural(number: &alignment) else { return nil }
                name = "M"
            } else if nextIf("m") {
                kind = .Identifier
                guard demangleNatural(number: &size) else { return nil }
                name = "m"
            } else {
                return nil
            }
            
            let second = Node(kind: kind, text: name)
            let reqt = Node(kind: .DependentGenericLayoutRequirement)
            reqt.add(constrainedType)
            reqt.add(second)
            if size != .max {
                reqt.add(kind: .Number, payload: .index(size))
                if alignment != .max {
                    reqt.add(kind: .Number, payload: .index(alignment))
                }
            }
            return reqt
        }
        
        // Base class constraints are introduced by a class type mangling, which
        // will begin with either 'C' or 'S'.
        guard isNotEmpty else { return nil }
        
        var constraint: Node?
        
        let next = peek()
        
        if next == "C" {
            constraint = demangleType()
            guard constraint.hasValue else { return nil }
        } else if (next == "S") {
            // A substitution may be either the module name of a protocol or a full
            // type name.
            var typeName: Node?
            self.next()
            guard let sub = demangleSubstitutionIndex() else { return nil }
            if sub.kind == .Protocol || sub.kind == .Class {
                typeName = sub
            } else if (sub.kind == .Module) {
                typeName = demangleProtocolNameGivenContext(sub)
                guard typeName.hasValue else { return nil }
            } else {
                return nil
            }
            constraint = Node(kind: .Type)
            constraint?.add(typeName)
        } else {
            constraint = demangleProtocolName()
            guard constraint.hasValue else { return nil }
        }
        
        let reqt = Node(kind: .DependentGenericConformanceRequirement)
        reqt.add(constrainedType)
        reqt.add(constraint)
        return reqt
    }
    
    func demangleArchetypeType() -> Node? {
        func makeAssociatedType(_ root: Node) -> Node? {
            guard let name = demangleIdentifier() else { return nil }
            let assocType = Node(kind: .AssociatedTypeRef)
            assocType.add(root)
            assocType.add(name)
            substitutions.append(assocType)
            return assocType
        }
        
        if nextIf("Q") {
            guard let root = demangleArchetypeType() else { return nil }
            return makeAssociatedType(root)
        }
        if nextIf("S") {
            guard let sub = demangleSubstitutionIndex() else { return nil }
            return makeAssociatedType(sub)
        }
        if nextIf("s") {
            return makeAssociatedType(.init(kind: .Module, text: .STDLIB_NAME))
        }
        return nil
    }
    
    func demangleTuple(_ isV: Node.IsVariadic) -> Node? {
        let tuple = Node(kind: .Tuple)
        var elt: Node = Node(kind: .EmptyList)
        while !nextIf("_") {
            guard isNotEmpty else { return nil }
            elt = Node(kind: .TupleElement)
            
            if isStartOfIdentifier(peek()) {
                guard let label = demangleIdentifier(kind: .TupleElementName) else { return nil }
                elt.add(label)
            }
            
            guard let type = demangleType() else { return nil }
            elt.add(type)
            
            tuple.add(elt)
        }
        if isV == .yes {
            elt.reverseChildren()
            let marker = Node(kind: .VariadicMarker)
            elt.add(marker)
            elt.reverseChildren()
            tuple.replaceLast(elt)
        }
        return tuple
    }
    
    func postProcessReturnTypeNode(_ out_args: Node) -> Node {
        let out_node = Node(kind: .ReturnType)
        out_node.add(out_args)
        return out_node
    }
    
    func demangleType() -> Node? {
        guard let type = demangleTypeImpl() else { return nil }
        let nodeType = Node(kind: .Type)
        nodeType.add(type)
        return nodeType
    }
    
    func demangleFunctionType(kind: Node.Kind) -> Node? {
        var isThrows = false
        var isConcurrent = false
        var isAsync = false
        var diffKind = MangledDifferentiabilityKind.nonDifferentiable
        var globalActorType: Node?
        if isNotEmpty {
            isThrows = nextIf("z")
            isConcurrent = nextIf("y")
            isAsync = nextIf("Z")
            
            if nextIf("D") {
                let kind = next().map(\.description).flatMap(MangledDifferentiabilityKind.init) ?? .nonDifferentiable
                switch kind {
                case .forward, .reverse, .normal, .linear:
                    diffKind = kind
                case .nonDifferentiable:
                    assertionFailure("Impossible case 'NonDifferentiable'")
                }
            }
            if nextIf("Y") {
                globalActorType = demangleType()
                if globalActorType == nil {
                    return nil
                }
            }
        }
        
        guard let in_args = demangleType() else { return nil }
        guard let out_args = demangleType() else { return nil }
        let block = Node(kind: kind)
        
        if isThrows {
            block.add(.ThrowsAnnotation)
        }
        if isAsync {
            block.add(.AsyncAnnotation)
        }
        if isConcurrent {
            block.add(.ConcurrentFunctionType)
        }
        if diffKind != .nonDifferentiable {
            block.add(Node(kind: .DifferentiableFunctionType, payload: .mangledDifferentiabilityKind(diffKind)))
        }
        
        if let globalActorType = globalActorType {
            let globalActorNode = Node(kind: .GlobalActorFunctionType)
            globalActorNode.add(globalActorType)
            block.add(globalActorNode)
        }
        
        let in_node = Node(kind: .ArgumentTuple)
        in_node.add(in_args)
        block.add(in_node)
        block.add(postProcessReturnTypeNode(out_args))
        return block
    }
    
    func demangleTypeImpl() -> Node? {
        guard isNotEmpty else { return nil }
        guard let c = next() else { return nil }
        if c == "B" {
            guard isNotEmpty else { return nil }
            guard let c = next() else { return nil }
            if c == "b" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.BridgeObject")
            }
            if c == "B" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.UnsafeValueBuffer")
            }
            if c == "f" {
                var size: Node.IndexType = .zero
                if demangleBuiltinSize(number: &size) {
                    return Node(kind: .BuiltinTypeName, text: "Builtin.FPIEEE\(size)")
                }
            }
            if c == "i" {
                var size: Node.IndexType = .zero
                if demangleBuiltinSize(number: &size) {
                    return Node(kind: .BuiltinTypeName, text: "Builtin.Int\(size)")
                }
            }
            if c == "v" {
                var elts: Node.IndexType = .zero
                if demangleNatural(number: &elts) {
                    guard nextIf("B") else { return nil }
                    if nextIf("i") {
                        var size: Node.IndexType = .zero
                        guard demangleBuiltinSize(number: &size) else { return nil }
                        return Node(kind: .BuiltinTypeName, text: "Builtin.Vec\(elts)xInt\(size)")
                    }
                    if nextIf("f") {
                        var size: Node.IndexType = .zero
                        guard demangleBuiltinSize(number: &size) else { return nil }
                        return Node(kind: .BuiltinTypeName, text: "Builtin.Vec\(elts)xFloat\(size)")
                    }
                    if nextIf("p") {
                        return Node(kind: .BuiltinTypeName, text: "Builtin.Vec\(elts)xRawPointer")
                    }
                }
            }
            if c == "O" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.UnknownObject")
            }
            if c == "o" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.NativeObject")
            }
            if c == "p" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.RawPointer")
            }
            if c == "t" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.SILToken")
            }
            if c == "w" {
                return Node(kind: .BuiltinTypeName, text: "Builtin.Word")
            }
            return nil
        }
        if c == "a" {
            return demangleDeclarationName(kind: .TypeAlias)
        }
        
        if c == "b" {
            return demangleFunctionType(kind: .ObjCBlock)
        }
        if c == "c" {
            return demangleFunctionType(kind: .CFunctionPointer)
        }
        if c == "D" {
            guard let type = demangleType() else { return nil }
            let dynamicSelf = Node(kind: .DynamicSelf)
            dynamicSelf.add(type)
            return dynamicSelf
        }
        if c == "E" {
            guard nextIf("RR") else { return nil }
            return Node(kind: .ErrorType)
        }
        if c == "F" {
            return demangleFunctionType(kind: .FunctionType)
        }
        if c == "f" {
            return demangleFunctionType(kind: .UncurriedFunctionType)
        }
        if c == "G" {
            return demangleBoundGenericType();
        }
        if c == "X" {
            if nextIf("b") {
                guard let type = demangleType() else { return nil }
                let boxType = Node(kind: .SILBoxType)
                boxType.add(type)
                return boxType
            }
            if nextIf("B") {
                var signature: Node?
                if nextIf("G") {
                    signature = demangleGenericSignature(isPseudogeneric: false)
                    if signature == nil {
                        return nil
                    }
                }
                let layout = Node(kind: .SILBoxLayout)
                while !nextIf("_") {
                    var kind: Node.Kind
                    if nextIf("m") {
                        kind = .SILBoxMutableField
                    } else if nextIf("i") {
                        kind = .SILBoxImmutableField
                    } else {
                        return nil
                    }
                    
                    guard let type = demangleType() else { return nil }
                    let field = Node(kind: kind)
                    field.add(type)
                    layout.add(field)
                }
                var genericArgs: Node?
                if signature != nil {
                    genericArgs = Node(kind: .TypeList)
                    while !nextIf("_") {
                        guard let type = demangleType() else { return nil }
                        genericArgs?.add(type)
                    }
                }
                let boxType = Node(kind: .SILBoxTypeWithLayout)
                boxType.add(layout)
                if let signature = signature {
                    boxType.add(signature)
                    assert(genericArgs != nil)
                    boxType.add(genericArgs)
                }
                return boxType
            }
        }
        if c == "K" {
            return demangleFunctionType(kind: .AutoClosureType)
        }
        if c == "M" {
            guard let type = demangleType() else { return nil }
            let metatype = Node(kind: .Metatype)
            metatype.add(type)
            return metatype
        }
        if c == "X" {
            if nextIf("M") {
                guard let metatypeRepr = demangleMetatypeRepresentation() else { return nil }
                
                guard let type = demangleType() else { return nil }
                let metatype = Node(kind: .Metatype)
                metatype.add(metatypeRepr)
                metatype.add(type)
                return metatype
            }
        }
        if c == "P" {
            if nextIf("M") {
                guard let type = demangleType() else { return nil }
                let metatype = Node(kind: .ExistentialMetatype)
                metatype.add(type)
                return metatype
            }
            
            return demangleProtocolList()
        }
        
        if c == "X" {
            if nextIf("P") {
                if nextIf("M") {
                    guard let metatypeRepr = demangleMetatypeRepresentation() else { return nil }
                    
                    guard let type = demangleType() else { return nil }
                    
                    let metatype = Node(kind: .ExistentialMetatype)
                    metatype.add(metatypeRepr)
                    metatype.add(type)
                    return metatype
                }
                
                return demangleProtocolList();
            }
        }
        if c == "Q" {
            if nextIf("u") {
                // Special mangling for opaque return type.
                return Node(kind: .OpaqueReturnType)
            }
            return demangleArchetypeType();
        }
        if c == "q" {
            return demangleDependentType();
        }
        if c == "x" {
            // Special mangling for the first generic param.
            return getDependentGenericParamType(depth: 0, index: 0)
        }
        if c == "w" {
            return demangleAssociatedTypeSimple()
        }
        if c == "W" {
            return demangleAssociatedTypeCompound()
        }
        if c == "R" {
            let in_out = Node(kind: .InOut)
            guard  let type = demangleTypeImpl() else { return nil }
            in_out.add(type)
            return in_out
        }
        if c == "k" {
            let noDerivative = Node(kind: .NoDerivative)
            guard let type = demangleTypeImpl() else { return nil }
            noDerivative.add(type)
            return noDerivative
        }
        if c == "S" {
            return demangleSubstitutionIndex()
        }
        if c == "T" {
            return demangleTuple(.no)
        }
        if c == "t" {
            return demangleTuple(.yes)
        }
        if c == "u" {
            guard let sig = demangleGenericSignature() else { return nil }
            guard let sub = demangleType() else { return nil }
            let dependentGenericType = Node(kind: .DependentGenericType)
            dependentGenericType.add(sig)
            dependentGenericType.add(sub)
            return dependentGenericType
        }
        if c == "X" {
            if nextIf("f") {
                return demangleFunctionType(kind: .ThinFunctionType)
            }
            if nextIf("o") {
                guard let type = demangleType() else { return nil }
                let unowned = Node(kind: .Unowned)
                unowned.add(type)
                return unowned
            }
            if nextIf("u") {
                guard let type = demangleType() else { return nil }
                let unowned = Node(kind: .Unmanaged)
                unowned.add(type)
                return unowned
            }
            if nextIf("w") {
                guard let type = demangleType() else { return nil }
                let weak = Node(kind: .Weak)
                weak.add(type)
                return weak
            }
            
            // type ::= 'XF' impl-function-type
            if nextIf("F") {
                return demangleImplFunctionType()
            }
            
            return nil
        }
        guard isStartOfNominalType(c) else { return nil }
        return demangleDeclarationName(kind: nominalTypeMarkerToNodeKind(c))
    }
    
    func demangleReabstractSignature(signature: inout Node) -> Bool {
        if nextIf("G") {
            guard let generics = demangleGenericSignature() else { return false }
            signature.add(generics)
        }
        
        guard let srcType = demangleType() else { return false }
        signature.add(srcType)
        
        guard let destType = demangleType() else { return false }
        signature.add(destType)
        
        return true
    }
    
    // impl-function-type ::= impl-callee-convention impl-function-attribute*
    //                        generics? '_' impl-parameter* '_' impl-result* '_'
    // impl-function-attribute ::= 'Cb'            // compatible with C block invocation function
    // impl-function-attribute ::= 'Cc'            // compatible with C global function
    // impl-function-attribute ::= 'Cm'            // compatible with Swift method
    // impl-function-attribute ::= 'CO'            // compatible with ObjC method
    // impl-function-attribute ::= 'Cw'            // compatible with protocol witness
    // impl-function-attribute ::= 'G'             // generic
    func demangleImplFunctionType() -> Node? {
        var type = Node(kind: .ImplFunctionType)
        
        guard demangleImplCalleeConvention(type: &type) else { return nil }
        
        if nextIf("C") {
            if nextIf("b") {
                addImplFunctionConvention(parent: &type, attr: "block")
            } else if nextIf("c") {
                addImplFunctionConvention(parent: &type, attr: "c")
            } else if nextIf("m") {
                addImplFunctionConvention(parent: &type, attr: "method")
            } else if nextIf("O") {
                addImplFunctionConvention(parent: &type, attr: "objc_method")
            } else if nextIf("w") {
                addImplFunctionConvention(parent: &type, attr: "witness_method")
            } else {
                return nil
            }
        }
        
        if nextIf("h") {
            addImplFunctionAttribute(parent: &type, attr: "@Sendable")
        }
        
        if nextIf("H") {
            addImplFunctionAttribute(parent: &type, attr: "@async")
        }
        
        // Enter a new generic context if this type is generic.
        // FIXME: replace with std::optional, when we have it.
        var isPseudogeneric = false
        if nextIf("G") || nextIf("g").bind(to: &isPseudogeneric) {
            guard let generics = demangleGenericSignature(isPseudogeneric: isPseudogeneric) else { return nil }
            type.add(generics)
        }
        
        // Expect the attribute terminator.
        guard nextIf("_") else { return nil }
        
        // Demangle the parameters.
        guard demangleImplParameters(parent: &type) else { return nil }
        
        // Demangle the result type.
        guard demangleImplResults(parent: &type) else { return nil }
        
        return type
    }
    
    enum ImplConventionContext {
        case Callee, Parameter, Result
        
        func to(callee: String = "", parameter: String = "", result: String = "") -> String {
            switch self {
            case .Callee:
                return callee
            case .Parameter:
                return parameter
            case .Result:
                return result
            }
        }
    }

    /// impl-convention ::= 'a'                     // direct, autoreleased
    /// impl-convention ::= 'd'                     // direct, no ownership transfer
    /// impl-convention ::= 'D'                     // direct, no ownership transfer,
    ///                                             // dependent on self
    /// impl-convention ::= 'g'                     // direct, guaranteed
    /// impl-convention ::= 'e'                     // direct, deallocating
    /// impl-convention ::= 'i'                     // indirect, ownership transfer
    /// impl-convention ::= 'l'                     // indirect, inout
    /// impl-convention ::= 'o'                     // direct, ownership transfer
    ///
    /// Returns an empty string otherwise.
    func demangleImplConvention(ctx: ImplConventionContext) -> String {
        if nextIf("a") {
            return ctx.to(result: "@autoreleased")
        }
        if nextIf("d") {
            return ctx.to(callee: "@callee_unowned", parameter: "@unowned", result: "@unowned")
        }
        if nextIf("D") {
            return ctx.to(result: "@unowned_inner_pointer")
        }
        if nextIf("g") {
            return ctx.to(callee: "@callee_guaranteed", parameter: "@guaranteed")
        }
        if nextIf("e") {
            return ctx.to(parameter: "@deallocating")
        }
        if nextIf("i") {
            return ctx.to(parameter: "@in", result: "@out")
        }
        if nextIf("l") {
            return ctx.to(parameter: "@inout")
        }
        if nextIf("o") {
            return ctx.to(callee: "@callee_owned", parameter: "@owned", result: "@owned")
        }
        return ""
    }

    // impl-callee-convention ::= 't'
    // impl-callee-convention ::= impl-convention
    func demangleImplCalleeConvention(type: inout Node) -> Bool {
        var attr = ""
        if nextIf("t") {
            attr = "@convention(thin)"
        } else {
            attr = demangleImplConvention(ctx: .Callee)
        }
        if attr.isEmpty {
            return false
        } else {
            type.add(Node(kind: .ImplConvention, text: attr))
            return true
        }
    }
    
    func addImplFunctionAttribute(parent: inout Node, attr: String, kind: Node.Kind = .ImplFunctionAttribute) {
        parent.add(kind: kind, text: attr)
    }

    func addImplFunctionConvention(parent: inout Node, attr: String) {
        let attrNode = Node(kind: .ImplFunctionConvention)
        attrNode.add(.init(kind: .ImplFunctionConventionName, text: attr))
        parent.add(attrNode)
    }

    // impl-parameter ::= impl-convention type
    func demangleImplParameters(parent: inout Node) -> Bool {
        while !nextIf("_") {
            guard let input = demangleImplParameterOrResult(kind: .ImplParameter) else { return false }
            parent.add(input)
        }
        return true
    }

    // impl-result ::= impl-convention type
    func demangleImplResults(parent: inout Node) -> Bool {
        while !nextIf("_") {
            guard let res = demangleImplParameterOrResult(kind: .ImplResult) else { return false }
            parent.add(res)
        }
        return true
    }
    
    func demangleImplParameterOrResult(kind: Node.Kind) -> Node? {
        var kind = kind
        if nextIf("z") {
            // Only valid for a result.
            guard kind == .ImplResult else { return nil }
            kind = .ImplErrorResult
        }
        
        let convCtx: ImplConventionContext
        if kind == .ImplParameter {
            convCtx = .Parameter
        } else if kind == .ImplResult || kind == .ImplErrorResult {
            convCtx = .Result
        } else {
            return nil
        }
        
        guard let convention = demangleImplConvention(ctx: convCtx).emptyToNil() else { return nil }
        guard let type = demangleType() else { return nil }
        
        let node = Node(kind: kind)
        node.add(kind: .ImplConvention, text: convention)
        node.add(type)
        
        return node
    }
    
    func demangleChildOrReturn(parent node: Node, kind: Node.Kind) -> Node? {
        switch kind {
        case .Global:
            if let global = demangleGlobal() {
                return node.adding(global)
            } else {
                return nil
            }
        case .Type:
            if let type = demangleType() {
                return node.adding(type)
            } else {
                return nil
            }
        case .ProtocolConformance:
            if let protoConfo = demangleProtocolConformance() {
                return node.adding(protoConfo)
            } else {
                return nil
            }
        default:
            break
        }
        return nil
    }
    
    func demangleChildAsNodeOrReturn(parent node: Node, kind: Node.Kind) -> Node? {
        switch kind {
        case .Directness:
            if let directness = demangleDirectness() {
                return node.adding(Node(kind: kind, payload: .directness(directness)))
            } else {
                return nil
            }
        default:
            break
        }
        return nil
    }
    
}

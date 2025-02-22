//
//  Demangler.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/06.
//

import Foundation

class Demangler: Demanglerable, Mangling {
    var mangled: Data
    var mangledOriginal: Data
    var position: Int { mangledOriginal.count - mangled.count }
    let numerics: [Character] = (0...9).map(\.description).map(Character.init)
    
    private(set) var substitutions: [Node] = []
    
    private var nodeStack: [Node] = []
    private let maxNumWords = 26
    private var words: [String] = []
    private var numWords: Int { words.count }
    
    private var IsOldFunctionTypeMangling: Bool = false
    
    typealias SymbolicReferenceResolver_t = (SymbolicReferenceKind, Node.Directness, Int, String) -> Node?
    private var SymbolicReferenceResolver: SymbolicReferenceResolver_t?
    
    required init(_ mangled: String) {
        self.mangled = mangled.data(using: .ascii) ?? Data()
        self.mangledOriginal = Data(self.mangled)
    }
    
    func demangleOldSymbolAsNode(_ mangled: String) -> Node? {
        OldDemangler(mangled).demangleTopLevel()
    }
    
    func demangleSymbol(_ SymbolicReferenceResolver: SymbolicReferenceResolver_t? = nil) -> Node? {
        self.SymbolicReferenceResolver = SymbolicReferenceResolver
        
        // Demangle old-style class and protocol names, which are still used in the
        // ObjC metadata.
        if nextIf("_Tt") {
            return demangleOldSymbolAsNode(self.text)
        }
        
        let PrefixLength = self.manglingPrefixLength(from: self.textOriginal)
        if PrefixLength == 0 {
            return nil
        }
        
        self.IsOldFunctionTypeMangling = self.isOldFunctionType(self.textOriginal)
        advanceOffset(PrefixLength)
        
        // If any other prefixes are accepted, please update Mangler::verify.
        
        if !parseAndPushNodes() {
            return nil
        }
        
        let topLevel = createNode(.Global)
        
        var Parent = topLevel
        while let FuncAttr = popNode(isFunctionAttr) {
            Parent.addChild(FuncAttr)
            if FuncAttr.getKind() == .PartialApplyForwarder || FuncAttr.getKind() == .PartialApplyObjCForwarder {
                Parent = FuncAttr
            }
        }
        for Nd in nodeStack {
            switch Nd.getKind() {
            case .Type:
                Parent.addChild(Nd.getFirstChild())
            default:
                Parent.addChild(Nd)
            }
        }
        if topLevel.getNumChildren() == 0 {
            return nil
        }
        
        return topLevel
    }
    
    func demangleType(_ SymbolicReferenceResolver: SymbolicReferenceResolver_t? = nil) -> Node? {
        self.SymbolicReferenceResolver = SymbolicReferenceResolver
        
        parseAndPushNodes()
        
        if let Result = popNode() {
            return Result
        }
        
        return createNode(.Suffix, self.textOriginal)
    }
    
    @discardableResult
    func parseAndPushNodes() -> Bool {
        while self.mangled.isNotEmpty {
            guard let Node = demangleOperator() else { return false }
            pushNode(Node)
        }
        return true
    }
    
    func demangleTypeMangling() -> Node? {
        let type = popNode(.Type)
        let LabelList = popFunctionParamLabels(type)
        var TypeMangling: Node? = createNode(.TypeMangling)

        addChild(TypeMangling, LabelList)
        TypeMangling = addChild(TypeMangling, type)
        return TypeMangling
    }
    
    func demangleSymbolicReference(_ rawKind: Character) -> Node? {
        // The symbolic reference is a 4-byte machine integer encoded in the following
        // four bytes.
        if mangled.count + 4 > mangledOriginal.size() {
            return nil
        }
        
        guard let value = nextNumber(UInt32.self) else { return nil }
        
        // Map the encoded kind to a specific kind and directness.
        let kind: SymbolicReferenceKind
        let direct: Node.Directness
        switch rawKind {
        case 1:
            kind = .Context
            direct = .direct
        case 2:
            kind = .Context
            direct = .indirect
        case 9:
            kind = .AccessorFunctionReference
            direct = .direct
        default:
            return nil
        }
        
        // Use the resolver, if any, to produce the demangling tree the symbolic
        // reference represents.
        var resolved: Node?
        if let resolver = self.SymbolicReferenceResolver {
            resolved = resolver(kind, direct, Int(value), self.text)
        }
        
        // With no resolver, or a resolver that failed, refuse to demangle further.
        if resolved == nil {
            return nil
        }
        
        // Types register as substitutions even when symbolically referenced.
        // OOPS: Except for opaque type references!
        if kind == .Context && resolved.getKind() != .OpaqueTypeDescriptorSymbolicReference && resolved.getKind() != .OpaqueReturnTypeOf {
            addSubstitution(resolved)
        }
        return resolved
    }
    
    func demangleTypeAnnotation() -> Node? {
        switch nextChar() {
        case "a":
            return createNode(.AsyncAnnotation)
        case "b":
            return createNode(.ConcurrentFunctionType)
        case "c":
            return createWithChild(.GlobalActorFunctionType, popTypeAndGetChild())
        case "i":
            return createType(createWithChild(.Isolated, popTypeAndGetChild()))
        case "j":
            return demangleDifferentiableFunctionType()
        case "k":
            return createType(createWithChild(.NoDerivative, popTypeAndGetChild()))
        default:
            return nil
        }
    }
    
    func demangleOperator() -> Node? {
        while true {
            let c = nextChar()
            switch c {
            case 0xFF:
                // A 0xFF byte is used as alignment padding for symbolic references
                // when the platform toolchain has alignment restrictions for the
                // relocations that form the reference value. It can be skipped.
                continue
            case 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC:
                return demangleSymbolicReference(c)
            case "A": return demangleMultiSubstitutions()
            case "B": return demangleBuiltinType()
            case "C": return demangleAnyGenericType(.Class)
            case "D": return demangleTypeMangling()
            case "E": return demangleExtensionContext()
            case "F": return demanglePlainFunction()
            case "G": return demangleBoundGenericType()
            case "H":
                switch nextChar() {
                case "A": return demangleDependentProtocolConformanceAssociated()
                case "C": return demangleConcreteProtocolConformance()
                case "D": return demangleDependentProtocolConformanceRoot()
                case "I": return demangleDependentProtocolConformanceInherited()
                case "P":
                    return createWithChild(.ProtocolConformanceRefInTypeModule, popProtocol())
                case "p":
                    return createWithChild(.ProtocolConformanceRefInProtocolModule, popProtocol())
                default:
                    pushBack()
                    pushBack()
                    return demangleIdentifier()
                }
            case "I": return demangleImplFunctionType()
            case "K": return createNode(.ThrowsAnnotation)
            case "L": return demangleLocalIdentifier()
            case "M": return demangleMetatype()
            case "N": return createWithChild(.TypeMetadata, popNode(.Type))
            case "O": return demangleAnyGenericType(.Enum)
            case "P": return demangleAnyGenericType(.Protocol)
            case "Q": return demangleArchetype()
            case "R": return demangleGenericRequirement()
            case "S": return demangleStandardSubstitution()
            case "T": return demangleThunkOrSpecialization()
            case "V": return demangleAnyGenericType(.Structure)
            case "W": return demangleWitness()
            case "X": return demangleSpecialType()
            case "Y": return demangleTypeAnnotation()
            case "Z": return createWithChild(.Static, popNode(isEntity))
            case "a": return demangleAnyGenericType(.TypeAlias)
            case "c": return popFunctionType(.FunctionType)
            case "d": return createNode(.VariadicMarker)
            case "f": return demangleFunctionEntity()
            case "g": return demangleRetroactiveConformance()
            case "h": return createType(createWithChild(.Shared, popTypeAndGetChild()))
            case "i": return demangleSubscript()
            case "l": return demangleGenericSignature(/*hasParamCounts*/ false)
            case "m": return createType(createWithChild(.Metatype, popNode(.Type)))
            case "n":
                return createType(createWithChild(.Owned, popTypeAndGetChild()))
            case "o": return demangleOperatorIdentifier()
            case "p": return demangleProtocolListType()
            case "q": return createType(demangleGenericParamIndex())
            case "r": return demangleGenericSignature(/*hasParamCounts*/ true)
            case "s": return createNode(.Module, .STDLIB_NAME)
            case "t": return popTuple()
            case "u": return demangleGenericType()
            case "v": return demangleVariable()
            case "w": return demangleValueWitness()
            case "x": return createType(getDependentGenericParamType(0, 0))
            case "y": return createNode(.EmptyList)
            case "z": return createType(createWithChild(.InOut, popTypeAndGetChild()))
            case "_": return createNode(.FirstElementMarker)
            case ".":
                // IRGen still uses '.<n>' to disambiguate partial apply thunks and
                // outlined copy functions. We treat such a suffix as "unmangled suffix".
                pushBack()
                return createNode(.Suffix, consumeAll())
            default:
                pushBack()
                return demangleIdentifier()
            }
        }
    }
    
    func demangleNatural() -> Int {
        if !peekChar().isDigit {
            return -1000
        }
        var num = 0
        while true {
            let c = peekChar()
            if !c.isDigit {
                return num
            }
            let newNum = (10 * num) + (c - "0")
            if newNum < num {
                return -1000
            }
            num = newNum
            nextChar()
        }
    }
    
    func demangleIndex() -> Int {
        if nextIf("_") {
            return 0
        }
        let num = demangleNatural()
        if num >= 0 && nextIf("_") {
            return num + 1
        }
        return -1000
    }
    
    func demangleIndexAsNode() -> Node? {
        let Idx = demangleIndex()
        if Idx >= 0 {
            return createNode(.Number, Idx)
        }
        return nil
    }
    
    func demangleMultiSubstitutions() -> Node? {
        var RepeatCount = -1
        while true {
            let c = nextChar()
            if c == .zero {
                // End of text.
                return nil
            }
            if c.isLowercase {
                // It's a substitution with an index < 26.
                guard let Nd = pushMultiSubstitutions(RepeatCount, c - "a") else { return nil }
                pushNode(Nd)
                RepeatCount = -1
                // A lowercase letter indicates that there are more substitutions to
                // follow.
                continue
            }
            if c.isUppercase {
                // The last substitution.
                return pushMultiSubstitutions(RepeatCount, c - "A")
            }
            if c == "_" {
                // The previously demangled number is actually not a repeat count but
                // the large (> 26) index of a substitution. Because it's an index we
                // have to add 27 and not 26.
                let Idx = RepeatCount + 27
                if Idx >= substitutions.size() {
                    return nil
                }
                return substitutions[Idx]
            }
            pushBack()
            // Not a letter? Then it can only be a natural number which might be the
            // repeat count or a large (> 26) substitution index.
            RepeatCount = demangleNatural()
            if RepeatCount < 0 {
                return nil
            }
        }
    }
    
    func demangleStandardSubstitution() -> Node? {
        let c = nextChar()
        switch c {
        case "o":
            return createNode(.Module, .MANGLING_MODULE_OBJC)
        case "C":
            return createNode(.Module, .MANGLING_MODULE_CLANG_IMPORTER)
        case "g":
            let OptionalTy = createType(createWithChildren(.BoundGenericEnum, createSwiftType(.Enum, "Optional"), createWithChild(.TypeList, popNode(.Type))))
            addSubstitution(OptionalTy)
            return OptionalTy
        default:
            pushBack()
            let RepeatCount = demangleNatural()
            if RepeatCount > maxRepeatCount {
                return nil
            }
            let secondLevelSubstitution = nextIf("c")
            if let Nd = createStandardSubstitution(nextChar(), secondLevelSubstitution) {
                if RepeatCount > 1 {
                    for _ in 0..<RepeatCount - 1 {
                        pushNode(Nd)
                    }
                }
                return Nd
            }
            return nil
        }
    }
    
    func demangleIdentifier() -> Node? {
        var hasWordSubsts = false
        var isPunycoded = false
        let c = peekChar()
        if !c.isDigit {
            return nil
        }
        if c == "0" {
            nextChar()
            if peekChar() == "0" {
                nextChar()
                isPunycoded = true
            } else {
                hasWordSubsts = true
            }
        }
        var Identifier = ""
        repeat {
            while hasWordSubsts && peekChar().isLetter {
                let c = nextChar()
                var WordIdx = 0
                if c.isLowercase {
                    WordIdx = c - "a"
                } else {
                    assert(c.isUppercase)
                    WordIdx = c - "A"
                    hasWordSubsts = false
                }
                if WordIdx >= numWords {
                    return nil
                }
                assert(WordIdx < maxNumWords)
                let Slice = words[WordIdx]
                Identifier.append(Slice)
            }
            if nextIf("0") {
                break
            }
            let numChars = demangleNatural()
            if numChars <= 0 {
                return nil
            }
            if isPunycoded {
                nextIf("_")
            }
            if self.position + numChars > mangledOriginal.size() {
                return nil
            }
            let Slice = slice(numChars)
            if isPunycoded {
                var PunycodedString: String = ""
                if let punycoded = Punycode(string: Slice).decode() {
                    PunycodedString = punycoded
                } else {
                    return nil
                }
                Identifier.append(PunycodedString)
            } else {
                Identifier.append(Slice)
                var wordStartPos = -1
                for Idx in 0...Slice.size() {
                    let c: Character = Idx < Slice.count ? Slice[Idx] : .zero
                    if wordStartPos >= 0 && c.isWordEnd(prevChar: Slice[Idx - 1]) {
                        if (Idx - wordStartPos >= 2 && numWords < maxNumWords) {
                            let word = Slice[wordStartPos..<Idx]
                            self.words.append(word.description)
                        }
                        wordStartPos = -1
                    }
                    if wordStartPos < 0 && c.isWordStart {
                        wordStartPos = Idx
                    }
                }
            }
            advanceOffset(numChars)
        } while hasWordSubsts
        
        if Identifier.empty() {
            return nil
        }
        let Ident = createNode(.Identifier, Identifier)
        addSubstitution(Ident)
        return Ident
    }
    
    func demangleOperatorIdentifier() -> Node? {
        guard let Ident = popNode(.Identifier) else { return nil }
        
        let op_char_table = "& @/= >    <*!|+?%-~   ^ ."
        
        var OpStr = ""
        for c in Ident.text {
            if c.asciiValue == nil {
                // Pass through Unicode characters.
                OpStr.push_back(c)
                continue
            }
            if !c.isLowercase {
                return nil
            }
            let o = op_char_table[c - "a"]
            if o == " " {
                return nil
            }
            OpStr.push_back(o)
        }
        switch nextChar() {
        case "i": return createNode(.InfixOperator, OpStr)
        case "p": return createNode(.PrefixOperator, OpStr)
        case "P": return createNode(.PostfixOperator, OpStr)
        default: return nil
        }
    }
    
    func demangleLocalIdentifier() -> Node? {
        if nextIf("L") {
            let discriminator = popNode(.Identifier)
            let name = popNode(isDeclName)
            return createWithChildren(.PrivateDeclName, discriminator, name)
        }
        if nextIf("l") {
            let discriminator = popNode(.Identifier)
            return createWithChild(.PrivateDeclName, discriminator)
        }
        if (peekChar() >= "a" && peekChar() <= "j") || (peekChar() >= "A" && peekChar() <= "J") {
            let relatedEntityKind = nextChar()
            let kindNd = createNode(.Identifier, relatedEntityKind)
            let name = popNode()
            let result = createNode(.RelatedEntityDeclName)
            addChild(result, kindNd)
            return addChild(result, name)
        }
        let discriminator = demangleIndexAsNode()
        let name = popNode(isDeclName)
        return createWithChildren(.LocalDeclName, discriminator, name)
    }
    
    func demangleBuiltinType() -> Node? {
        var Ty: Node?
        let maxTypeSize = 4096 // a very conservative upper bound
        switch nextChar() {
        case "b":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_BRIDGEOBJECT)
        case "B":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_UNSAFEVALUEBUFFER)
        case "e":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_EXECUTOR)
        case "f":
            let size = demangleIndex() - 1
            if size <= 0 || size > maxTypeSize {
                return nil
            }
            var name = ""
            name.append(.BUILTIN_TYPE_NAME_FLOAT)
            name.append(size.description)
            Ty = createNode(.BuiltinTypeName, name)
        case "i":
            let size = demangleIndex() - 1
            if size <= 0 || size > maxTypeSize {
                return nil
            }
            var name = ""
            name.append(.BUILTIN_TYPE_NAME_INT)
            name.append(size.description)
            Ty = createNode(.BuiltinTypeName, name)
        case "I":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_INTLITERAL)
        case "v":
            let elts = demangleIndex() - 1
            if elts <= 0 || elts > maxTypeSize {
                return nil
            }
            let EltType = popTypeAndGetChild()
            if !EltType || EltType.getKind() != .BuiltinTypeName || !EltType.getText().hasPrefix(.BUILTIN_TYPE_NAME_PREFIX) {
                return nil
            }
            var name = ""
            name.append(.BUILTIN_TYPE_NAME_VEC)
            name.append(elts.description)
            name.push_back("x")
            name.append(EltType.getText().substr(String.BUILTIN_TYPE_NAME_PREFIX.size()))
            Ty = createNode(.BuiltinTypeName, name)
        case "O":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_UNKNOWNOBJECT)
        case "o":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_NATIVEOBJECT)
        case "p":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_RAWPOINTER)
        case "j":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_JOB)
        case "D":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_DEFAULTACTORSTORAGE)
        case "c":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_RAWUNSAFECONTINUATION)
        case "t":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_SILTOKEN)
        case "w":
            Ty = createNode(.BuiltinTypeName, .BUILTIN_TYPE_NAME_WORD)
        default:
            return nil
        }
        return createType(Ty)
    }
    
    func demangleAnyGenericType(_ kind: Node.Kind) -> Node? {
        let Name = popNode(isDeclName)
        let Ctx = popContext()
        let NTy = createType(createWithChildren(kind, Ctx, Name))
        addSubstitution(NTy)
        return NTy
    }
    
    func demangleExtensionContext() -> Node? {
        let GenSig = popNode(.DependentGenericSignature)
        let Module = popModule()
        let type = popTypeAndGetAnyGeneric()
        var Ext = createWithChildren(.Extension, Module, type)
        if let gensig = GenSig {
            Ext = addChild(Ext, gensig)
        }
        return Ext
    }
    
    func demanglePlainFunction() -> Node? {
        let GenSig = popNode(.DependentGenericSignature)
        var type = popFunctionType(.FunctionType)
        let LabelList = popFunctionParamLabels(type)
        
        if GenSig.hasValue {
            type = createType(createWithChildren(.DependentGenericType, GenSig, type))
        }
        
        let Name = popNode(isDeclName)
        let Ctx = popContext()
        
        if LabelList.hasValue {
            return createWithChildren(.Function, Ctx, Name, LabelList, type)
        }
        
        return createWithChildren(.Function, Ctx, Name, type)
    }
    
    func demangleRetroactiveProtocolConformanceRef() -> Node? {
        let module = popModule()
        let proto = popProtocol()
        let protocolConformanceRef = createWithChildren(.ProtocolConformanceRefInOtherModule, proto, module)
        return protocolConformanceRef
    }
    
    func demangleConcreteProtocolConformance() -> Node? {
        let conditionalConformanceList = popAnyProtocolConformanceList()
        
        var conformanceRef = popNode(.ProtocolConformanceRefInTypeModule)
        if conformanceRef == nil {
            conformanceRef = popNode(.ProtocolConformanceRefInProtocolModule)
        }
        if !conformanceRef {
            conformanceRef = demangleRetroactiveProtocolConformanceRef()
        }
        
        let type = popNode(.Type)
        return createWithChildren(.ConcreteProtocolConformance, type, conformanceRef, conditionalConformanceList)
    }
    
    func demangleDependentProtocolConformanceRoot() -> Node? {
        let index = demangleDependentConformanceIndex()
        let proto = popProtocol()
        let dependentType = popNode(.Type)
        return createWithChildren(.DependentProtocolConformanceRoot, dependentType, proto, index)
    }
    
    func demangleDependentProtocolConformanceInherited() -> Node? {
        let index = demangleDependentConformanceIndex()
        let proto = popProtocol()
        let nested = popDependentProtocolConformance()
        return createWithChildren(.DependentProtocolConformanceInherited, nested, proto, index)
    }
    
    func demangleDependentProtocolConformanceAssociated() -> Node? {
        let index = demangleDependentConformanceIndex()
        let associatedConformance = popDependentAssociatedConformance()
        let nested = popDependentProtocolConformance()
        return createWithChildren(.DependentProtocolConformanceAssociated, nested, associatedConformance, index)
    }
    
    func demangleDependentConformanceIndex() -> Node? {
        let index = demangleIndex()
        // index < 0 indicates a demangling error.
        // index == 0 is ill-formed by the (originally buggy) use of this production.
        guard index > 0 else { return nil }
        
        // index == 1 indicates an unknown index.
        guard index != 1 else { return createNode(.UnknownIndex) }
        
        // Remove the index adjustment.
        return createNode(.Index, index - 2)
    }
    
    func demangleRetroactiveConformance() -> Node? {
        let index = demangleIndexAsNode()
        let conformance = popAnyProtocolConformance()
        return createWithChildren(.RetroactiveConformance, index, conformance)
    }
    
    func demangleBoundGenerics(_ TypeListList: inout [Node], _ RetroactiveConformances: inout Node?) -> Bool {
        var RetroactiveConformances: Node?
        while let RetroactiveConformance = popNode(.RetroactiveConformance) {
            if RetroactiveConformances == nil {
                RetroactiveConformances = createNode(.TypeList)
            }
            RetroactiveConformances.addChild(RetroactiveConformance)
        }
        RetroactiveConformances.reverseChildren()
        
        while true {
            let TList = createNode(.TypeList)
            TypeListList.push_back(TList)
            while let Ty = popNode(.Type) {
                TList.addChild(Ty)
            }
            TList.reverseChildren()
            
            if popNode(.EmptyList).hasValue {
                break
            }
            if popNode(.FirstElementMarker) == nil {
                return false
            }
        }
        return true
    }
    func demangleBoundGenericType() -> Node? {
        var RetroactiveConformances: Node?
        var TypeListList: [Node] = []
        
        guard demangleBoundGenerics(&TypeListList, &RetroactiveConformances) else { return nil }
        guard let Nominal = popTypeAndGetAnyGeneric() else { return nil }
        guard let BoundNode = demangleBoundGenericArgs(Nominal, &TypeListList, 0) else { return nil }
        addChild(BoundNode, RetroactiveConformances)
        let NTy = createType(BoundNode)
        addSubstitution(NTy)
        return NTy
    }
    
    func demangleBoundGenericArgs(_ Nominal: Node?, _ TypeLists: inout [Node], _ TypeListIdx: Int) -> Node? {
        // TODO: This would be a lot easier if we represented bound generic args
        // flatly in the demangling tree, since that's how they're mangled and also
        // how the runtime generally wants to consume them.
        
        guard let Nominal = Nominal else { return nil }
        guard TypeListIdx < TypeLists.count else { return nil }
        
        // Associate a context symbolic reference with all remaining generic
        // arguments.
        if Nominal.getKind() == .TypeSymbolicReference || Nominal.getKind() == .ProtocolSymbolicReference {
            let remainingTypeList = createNode(.TypeList)
            for list in TypeLists.reversed() {
                for child in list.copyOfChildren {
                    remainingTypeList.addChild(child)
                }
            }
            return createWithChildren(.BoundGenericOtherNominalType, createType(Nominal), remainingTypeList)
        }
        
        // Generic arguments for the outermost type come first.
        guard Nominal.numberOfChildren > 0 else { return nil }
        let Context = Nominal.getFirstChild()
        
        let consumesGenericArgs = nodeConsumesGenericArgs(Nominal)
        
        let args = TypeLists[TypeListIdx]
        
        var TypeListIdx = TypeListIdx
        if consumesGenericArgs {
            ++TypeListIdx
        }
        
        var nominal = Nominal
        if TypeListIdx < TypeLists.size() {
            var BoundParent: Node?
            if Context.getKind() == .Extension {
                BoundParent = demangleBoundGenericArgs(Context.getChild(1), &TypeLists, TypeListIdx)
                BoundParent = createWithChildren(.Extension, Context.getFirstChild(), BoundParent)
                if Context.getNumChildren() == 3 {
                    // Add the generic signature of the extension context.
                    addChild(BoundParent, Context.getChild(2))
                }
            } else {
                BoundParent = demangleBoundGenericArgs(Context, &TypeLists, TypeListIdx)
            }
            // Rebuild this type with the new parent type, which may have
            // had its generic arguments applied.
            guard let NewNominal = createWithChild(nominal.getKind(), BoundParent) else { return nil }
            
            // Append remaining children of the origin nominal.
            for child in nominal.copyOfChildren.dropFirst() {
                addChild(NewNominal, child)
            }
            nominal = NewNominal
        }
        if !consumesGenericArgs {
            return nominal
        }
        
        // If there were no arguments at this level there is nothing left
        // to do.
        if args.getNumChildren() == 0 {
            return nominal
        }
        
        let kind: Node.Kind
        switch nominal.getKind() {
        case .Class:
            kind = .BoundGenericClass
        case .Structure:
            kind = .BoundGenericStructure
        case .Enum:
            kind = .BoundGenericEnum
        case .Protocol:
            kind = .BoundGenericProtocol
        case .OtherNominalType:
            kind = .BoundGenericOtherNominalType
        case .TypeAlias:
            kind = .BoundGenericTypeAlias
        case .Function, .Constructor:
            // Well, not really a nominal type.
            return createWithChildren(.BoundGenericFunction, nominal, args)
        default:
            return nil
        }
        return createWithChildren(kind, createType(nominal), args)
    }
    
    func demangleImplParamConvention(_ ConvKind: Node.Kind) -> Node? {
        let attr: String
        switch nextChar() {
        case "i": attr = "@in"
        case "c":
            attr = "@in_constant"
        case "l": attr = "@inout"
        case "b": attr = "@inout_aliasable"
        case "n": attr = "@in_guaranteed"
        case "x": attr = "@owned"
        case "g": attr = "@guaranteed"
        case "e": attr = "@deallocating"
        case "y": attr = "@unowned"
        default:
            pushBack()
            return nil
        }
        return createWithChild(ConvKind, createNode(.ImplConvention, attr))
    }
    
    func demangleImplResultConvention(_ ConvKind: Node.Kind) -> Node? {
        let attr: String
        switch nextChar() {
        case "r": attr = "@out"
        case "o": attr = "@owned"
        case "d": attr = "@unowned"
        case "u": attr = "@unowned_inner_pointer"
        case "a": attr = "@autoreleased"
        default:
            pushBack()
            return nil
        }
        return createWithChild(ConvKind, createNode(.ImplConvention, attr))
    }
    
    func demangleImplParameterResultDifferentiability() -> Node? {
        // Empty string represents default differentiability.
        let attr: String
        if nextIf("w") {
            attr = "@noDerivative"
        } else {
            attr = ""
        }
        return createNode(.ImplParameterResultDifferentiability, attr)
    }
    
    func demangleClangType() -> Node? {
        let numChars = demangleNatural()
        guard numChars > 0, self.position + mangled.count <= mangledOriginal.count else { return nil }
        var mangledClangType: String = ""
        mangledClangType.append(nextString(numChars))
        return createNode(.ClangType, mangledClangType)
    }
    
    func demangleImplFunctionType() -> Node? {
        var type: Node? = createNode(.ImplFunctionType)
        
        if nextIf("s") {
            var Substitutions: [Node] = []
            var SubstitutionRetroConformances: Node?
            if !demangleBoundGenerics(&Substitutions, &SubstitutionRetroConformances) { return nil }
            
            let sig = popNode(.DependentGenericSignature)
            if !sig { return nil }
            
            let subsNode = createNode(.ImplPatternSubstitutions)
            subsNode.addChild(sig)
            assert(Substitutions.size() == 1)
            subsNode.addChild(Substitutions[0])
            if SubstitutionRetroConformances.hasValue {
                subsNode.addChild(SubstitutionRetroConformances)
            }
            type.addChild(subsNode)
        }
        
        if nextIf("I") {
            var Substitutions: [Node] = []
            var SubstitutionRetroConformances: Node?
            if !demangleBoundGenerics(&Substitutions, &SubstitutionRetroConformances) { return nil }
            
            let subsNode = createNode(.ImplInvocationSubstitutions)
            assert(Substitutions.size() == 1)
            subsNode.addChild(Substitutions[0])
            if SubstitutionRetroConformances.hasValue {
                subsNode.addChild(SubstitutionRetroConformances)
            }
            type.addChild(subsNode)
        }
        
        var GenSig = popNode(.DependentGenericSignature)
        if GenSig.hasValue && nextIf("P") {
            GenSig = changeKind(GenSig, .DependentPseudogenericSignature)
        }
        
        if nextIf("e") { type.addChild(createNode(.ImplEscaping)) }
        
        switch MangledDifferentiabilityKind(rawValue: peekChar().description) {
        case .normal,  // "d"
                .linear,  // "l"
                .forward, // "f"
                .reverse: // "r"
            type.addChild(createNode(.ImplDifferentiabilityKind, nextChar()))
        default:
            break
        }
        
        let CAttr: String
        switch nextChar() {
        case "y": CAttr = "@callee_unowned"
        case "g": CAttr = "@callee_guaranteed"
        case "x": CAttr = "@callee_owned"
        case "t": CAttr = "@convention(thin)"
        default: return nil
        }
        type.addChild(createNode(.ImplConvention, CAttr))
        
        var FConv: String = ""
        var hasClangType = false
        switch nextChar() {
        case "B": FConv = "block"
        case "C": FConv = "c"
        case "z":
            switch nextChar() {
            case "B": hasClangType = true; FConv = "block"
            case "C": hasClangType = true; FConv = "c"
            default:
                pushBack()
                pushBack()
            }
        case "M": FConv = "method"
        case "O": FConv = "objc_method"
        case "K": FConv = "closure"
        case "W": FConv = "witness_method"
        default: pushBack()
        }
        if FConv.isNotEmpty {
            let FAttrNode = createNode(.ImplFunctionConvention)
            FAttrNode.addChild(createNode(.ImplFunctionConventionName, FConv))
            if hasClangType {
                FAttrNode.addChild(demangleClangType())
            }
            type.addChild(FAttrNode)
        }
        
        var CoroAttr: String?
        if nextIf("A") { CoroAttr = "@yield_once" }
        else if nextIf("G") { CoroAttr = "@yield_many" }
        if let CoroAttr = CoroAttr {
            type.addChild(createNode(.ImplFunctionAttribute, CoroAttr))
        }
        
        if nextIf("h") {
            type.addChild(createNode(.ImplFunctionAttribute, "@Sendable"))
        }
        
        if nextIf("H") {
            type.addChild(createNode(.ImplFunctionAttribute, "@async"))
        }
        
        addChild(type, GenSig)
        
        var NumTypesToAdd = 0
        var Param: Node?
        while let param = demangleImplParamConvention(.ImplParameter) {
            type = addChild(type, param)
            if let Diff = demangleImplParameterResultDifferentiability() {
                Param = addChild(param, Diff)
            }
            ++NumTypesToAdd
            if Param == nil {
                break
            }
        }
        var Result: Node?
        while let result = demangleImplResultConvention(.ImplResult) {
            type = addChild(type, result)
            if let Diff = demangleImplParameterResultDifferentiability() {
                Result = addChild(result, Diff)
            }
            ++NumTypesToAdd
            if Result == nil {
                break
            }
        }
        while nextIf("Y") {
            let YieldResult =
            demangleImplParamConvention(.ImplYield)
            if !YieldResult { return nil }
            type = addChild(type, YieldResult)
            ++NumTypesToAdd
        }
        if nextIf("z") {
            let ErrorResult = demangleImplResultConvention(
                .ImplErrorResult)
            if !ErrorResult { return nil }
            type = addChild(type, ErrorResult)
            ++NumTypesToAdd
        }
        if !nextIf("_") { return nil }
        
        for Idx in 0..<NumTypesToAdd {
            let ConvTy = popNode(.Type)
            if !ConvTy { return nil }
            type.getChild(type.getNumChildren() - Idx - 1).addChild(ConvTy)
        }
        
        return createType(type)
    }
    
    func demangleMetatype() -> Node? {
        switch nextChar() {
        case "a":
            return createWithPoppedType(.TypeMetadataAccessFunction)
        case "A":
            return createWithChild(.ReflectionMetadataAssocTypeDescriptor, popProtocolConformance())
        case "b":
            return createWithPoppedType(.CanonicalSpecializedGenericTypeMetadataAccessFunction)
        case "B":
            return createWithChild(.ReflectionMetadataBuiltinDescriptor, popNode(.Type))
        case "c":
            return createWithChild(.ProtocolConformanceDescriptor, popProtocolConformance())
        case "C":
            guard let Ty = popNode(.Type), Ty.getChild(0).getKind().isAnyGeneric else { return nil }
            return createWithChild(.ReflectionMetadataSuperclassDescriptor, Ty.getChild(0))
        case "D":
            return createWithPoppedType(.TypeMetadataDemanglingCache)
        case "f":
            return createWithPoppedType(.FullTypeMetadata)
        case "F":
            return createWithChild(.ReflectionMetadataFieldDescriptor, popNode(.Type))
        case "g":
            return createWithChild(.OpaqueTypeDescriptorAccessor, popNode())
        case "h":
            return createWithChild(.OpaqueTypeDescriptorAccessorImpl, popNode())
        case "i":
            return createWithPoppedType(.TypeMetadataInstantiationFunction)
        case "I":
            return createWithPoppedType(.TypeMetadataInstantiationCache)
        case "j":
            return createWithChild(.OpaqueTypeDescriptorAccessorKey, popNode())
        case "J":
            return createWithChild(.NoncanonicalSpecializedGenericTypeMetadataCache, popNode())
        case "k":
            return createWithChild(.OpaqueTypeDescriptorAccessorVar, popNode())
        case "K":
            return createWithChild(.MetadataInstantiationCache, popNode())
        case "l":
            return createWithPoppedType(.TypeMetadataSingletonInitializationCache)
        case "L":
            return createWithPoppedType(.TypeMetadataLazyCache)
        case "m":
            return createWithPoppedType(.Metaclass)
        case "M":
            return createWithPoppedType(.CanonicalSpecializedGenericMetaclass)
        case "n":
            return createWithPoppedType(.NominalTypeDescriptor)
        case "N":
            return createWithPoppedType(.NoncanonicalSpecializedGenericTypeMetadata)
        case "o":
            return createWithPoppedType(.ClassMetadataBaseOffset)
        case "p":
            return createWithChild(.ProtocolDescriptor, popProtocol())
        case "P":
            return createWithPoppedType(.GenericTypeMetadataPattern)
        case "Q":
            return createWithChild(.OpaqueTypeDescriptor, popNode())
        case "r":
            return createWithPoppedType(.TypeMetadataCompletionFunction)
        case "s":
            return createWithPoppedType(.ObjCResilientClassStub)
        case "S":
            return createWithChild(.ProtocolSelfConformanceDescriptor, popProtocol())
        case "t":
            return createWithPoppedType(.FullObjCResilientClassStub)
        case "u":
            return createWithPoppedType(.MethodLookupFunction)
        case "U":
            return createWithPoppedType(.ObjCMetadataUpdateFunction)
        case "V":
            return createWithChild(.PropertyDescriptor, popNode(isEntity))
        case "X":
            return demanglePrivateContextDescriptor()
        case "z":
            return createWithPoppedType(.CanonicalPrespecializedGenericTypeCachingOnceToken)
        default:
            return nil
        }
    }
    
    func demanglePrivateContextDescriptor() -> Node? {
        switch nextChar() {
        case "E":
            guard let Extension = popContext() else { return nil }
            return createWithChild(.ExtensionDescriptor, Extension)
        case "M":
            guard let Module = popModule() else { return nil }
            return createWithChild(.ModuleDescriptor, Module)
        case "Y":
            guard let Discriminator = popNode() else { return nil }
            guard let Context = popContext() else { return nil }
            
            let node = createNode(.AnonymousDescriptor)
            node.addChild(Context)
            node.addChild(Discriminator)
            return node
        case "X":
            guard let Context = popContext() else { return nil }
            return createWithChild(.AnonymousDescriptor, Context)
        case "A":
            guard let path = popAssocTypePath() else { return nil }
            guard let base = popNode(.Type) else { return nil }
            return createWithChildren(.AssociatedTypeGenericParamRef, base, path)
        default:
            return nil
        }
    }
    
    func demangleArchetype() -> Node? {
        switch nextChar() {
        case "a":
            let Ident = popNode(.Identifier)
            let ArcheTy = popTypeAndGetChild()
            let AssocTy = createType(createWithChildren(.AssociatedTypeRef, ArcheTy, Ident))
            addSubstitution(AssocTy)
            return AssocTy
        case "O":
            let definingContext = popContext()
            return createWithChild(.OpaqueReturnTypeOf, definingContext)
        case "o":
            let index = demangleIndex()
            var boundGenericArgs: [Node] = []
            var retroactiveConformances: Node?
            if !demangleBoundGenerics(&boundGenericArgs, &retroactiveConformances) {
                return nil
            }
            guard let Name = popNode() else { return nil }
            let opaque = createWithChildren(.OpaqueType, Name, createNode(.Index, index))
            let boundGenerics = createNode(.TypeList)
            for node in boundGenericArgs.reversed() {
                boundGenerics.addChild(node)
            }
            opaque.addChild(boundGenerics)
            if let retroactiveConformances = retroactiveConformances {
                opaque.addChild(retroactiveConformances)
            }
            
            let opaqueTy = createType(opaque)
            addSubstitution(opaqueTy)
            return opaqueTy
        case "r":
            return createType(createNode(.OpaqueReturnType))
        case "x":
            let T = demangleAssociatedTypeSimple()
            addSubstitution(T)
            return T
        case "X":
            let T = demangleAssociatedTypeCompound()
            addSubstitution(T)
            return T
        case "y":
            let T = demangleAssociatedTypeSimple(demangleGenericParamIndex())
            addSubstitution(T)
            return T
        case "Y":
            let T = demangleAssociatedTypeCompound(demangleGenericParamIndex())
            addSubstitution(T)
            return T
        case "z":
            let T = demangleAssociatedTypeSimple(getDependentGenericParamType(0, 0))
            addSubstitution(T)
            return T
        case "Z":
            let T = demangleAssociatedTypeCompound(getDependentGenericParamType(0, 0))
            addSubstitution(T)
            return T
        default:
            return nil
        }
    }
    
    func demangleAssociatedTypeSimple(_ Base: Node? = nil) -> Node? {
        let ATName = popAssocTypeName()
        var BaseTy: Node?
        if Base.hasValue {
            BaseTy = createType(Base)
        } else {
            BaseTy = popNode(.Type)
        }
        return createType(createWithChildren(.DependentMemberType, BaseTy, ATName))
    }
    
    func demangleAssociatedTypeCompound(_ Base: Node? = nil) -> Node? {
        var AssocTyNames: [Node] = []
        var firstElem = false
        repeat {
            firstElem = popNode(.FirstElementMarker).hasValue
            guard let AssocTyName = popAssocTypeName() else { return nil }
            AssocTyNames.push_back(AssocTyName)
        } while !firstElem
        
        var BaseTy: Node?
        if let base = Base {
            BaseTy = createType(base)
        } else {
            BaseTy = popNode(.Type)
        }
        
        while let AssocTy = AssocTyNames.popLast() {
            var depTy: Node? = createNode(.DependentMemberType)
            depTy = addChild(depTy, BaseTy)
            BaseTy = createType(addChild(depTy, AssocTy))
        }
        return BaseTy
    }
    
    func demangleGenericParamIndex() -> Node? {
        if nextIf("d") {
            let depth = demangleIndex() + 1
            let index = demangleIndex()
            return getDependentGenericParamType(depth, index)
        }
        if nextIf("z") {
            return getDependentGenericParamType(0, 0)
        }
        return getDependentGenericParamType(0, demangleIndex() + 1)
    }
    
    func demangleThunkOrSpecialization() -> Node? {
        let c = nextChar()
        switch c {
        case "c":
            return createWithChild(.CurryThunk, popNode(isEntity))
        case "j":
            return createWithChild(.DispatchThunk, popNode(isEntity))
        case "q":
            return createWithChild(.MethodDescriptor, popNode(isEntity))
        case "o":
            return createNode(.ObjCAttribute)
        case "O":
            return createNode(.NonObjCAttribute)
        case "D":
            return createNode(.DynamicAttribute)
        case "d":
            return createNode(.DirectMethodReferenceAttribute)
        case "a":
            return createNode(.PartialApplyObjCForwarder)
        case "A":
            return createNode(.PartialApplyForwarder)
        case "m":
            return createNode(.MergedFunction)
        case "X":
            return createNode(.DynamicallyReplaceableFunctionVar)
        case "x":
            return createNode(.DynamicallyReplaceableFunctionKey)
        case "I":
            return createNode(.DynamicallyReplaceableFunctionImpl)
        case "Y", "Q":
            let discriminator = demangleIndexAsNode()
            return createWithChild(c == "Q" ? .AsyncAwaitResumePartialFunction : .AsyncSuspendResumePartialFunction, discriminator)
        case "C":
            let type = popNode(.Type)
            return createWithChild(.CoroutineContinuationPrototype, type)
        case "z", "Z":
            let flagMode = demangleIndexAsNode()
            let sig = popNode(.DependentGenericSignature)
            let resultType = popNode(.Type)
            let implType = popNode(.Type)
            let node = createWithChildren(c == "z" ? .ObjCAsyncCompletionHandlerImpl : .PredefinedObjCAsyncCompletionHandlerImpl, implType, resultType, flagMode)
            if sig.hasValue {
                addChild(node, sig)
            }
            return node
        case "V":
            let Base = popNode(isEntity)
            let Derived = popNode(isEntity)
            return createWithChildren(.VTableThunk, Derived, Base)
        case "W":
            let Entity = popNode(isEntity)
            let Conf = popProtocolConformance()
            return createWithChildren(.ProtocolWitness, Conf, Entity)
        case "S":
            return createWithChild(.ProtocolSelfConformanceWitness, popNode(isEntity))
        case "R", "r", "y":
            let kind: Node.Kind
            if c == "R" { kind = .ReabstractionThunkHelper }
            else if c == "y" { kind = .ReabstractionThunkHelperWithSelf }
            else { kind = .ReabstractionThunk }
            let Thunk = createNode(kind)
            if let GenSig = popNode(.DependentGenericSignature) {
                addChild(Thunk, GenSig)
            }
            if kind == .ReabstractionThunkHelperWithSelf {
                addChild(Thunk, popNode(.Type))
            }
            addChild(Thunk, popNode(.Type))
            addChild(Thunk, popNode(.Type))
            return Thunk
        case "g":
            return demangleGenericSpecialization(.GenericSpecialization)
        case "G":
            return demangleGenericSpecialization(.GenericSpecializationNotReAbstracted)
        case "B":
            return demangleGenericSpecialization(.GenericSpecializationInResilienceDomain)
        case "s":
            return demangleGenericSpecialization(.GenericSpecializationPrespecialized)
        case "i":
            return demangleGenericSpecialization(.InlinedGenericFunction)
        case "p":
            let Spec = demangleSpecAttributes(.GenericPartialSpecialization)
            let Param = createWithChild(.GenericSpecializationParam, popNode(.Type))
            return addChild(Spec, Param)
        case"P":
            let Spec = demangleSpecAttributes(.GenericPartialSpecializationNotReAbstracted)
            let Param = createWithChild(.GenericSpecializationParam, popNode(.Type))
            return addChild(Spec, Param)
        case"f":
            return demangleFunctionSpecialization()
        case "K", "k":
            let nodeKind: Node.Kind = c == "K" ? .KeyPathGetterThunkHelper : .KeyPathSetterThunkHelper
            
            let isSerialized = nextIf("q")
            
            var types: [Node] = []
            var node = popNode()
            if node == nil || node?.getKind() != .Type {
                return nil
            }
            repeat {
                types.append(node)
                node = popNode()
            } while node.hasValue && node.getKind() == .Type
            
            var result: Node?
            if node.hasValue {
                if node.getKind() == .DependentGenericSignature {
                    guard let decl = popNode() else { return nil }
                    result = createWithChildren(nodeKind, decl, /*sig*/ node)
                } else {
                    result = createWithChild(nodeKind, /*decl*/ node)
                }
            } else {
                return nil
            }
            for node in types.reversed() {
                result.add(node)
            }
            
            if isSerialized {
                result.addChild(createNode(.IsSerialized))
            }
            
            return result
        case "l":
            guard let assocTypeName = popAssocTypeName() else { return nil }
            
            return createWithChild(.AssociatedTypeDescriptor, assocTypeName)
        case "L":
            return createWithChild(.ProtocolRequirementsBaseDescriptor, popProtocol())
        case "M":
            return createWithChild(.DefaultAssociatedTypeMetadataAccessor, popAssocTypeName())
            
        case "n":
            let requirementTy = popProtocol()
            let conformingType = popSelfOrAssocTypePath()
            let protoTy = popNode(.Type)
            return createWithChildren(.AssociatedConformanceDescriptor, protoTy, conformingType, requirementTy)
        case "N":
            let requirementTy = popProtocol()
            let assocTypePath = popSelfOrAssocTypePath()
            let protoTy = popNode(.Type)
            return createWithChildren(.DefaultAssociatedConformanceAccessor, protoTy, assocTypePath, requirementTy)
        case "b":
            let requirementTy = popProtocol()
            let protoTy = popNode(.Type)
            return createWithChildren(.BaseConformanceDescriptor, protoTy, requirementTy)
        case "H", "h":
            let nodeKind: Node.Kind = c == "H" ? .KeyPathEqualsThunkHelper : .KeyPathHashThunkHelper
            
            let isSerialized = nextIf("q")
            
            var genericSig: Node?
            var types: [Node] = []
            
            if let node = popNode() {
                if node.getKind() == .DependentGenericSignature {
                    genericSig = node
                } else if node.getKind() == .Type {
                    types.append(node)
                } else {
                    return nil
                }
            } else {
                return nil
            }
            
            while let node = popNode() {
                if node.getKind() != .Type {
                    return nil
                }
                types.push_back(node)
            }
            
            let result = createNode(nodeKind)
            for type in types.reversed() {
                result.addChild(type)
            }
            if genericSig.hasValue {
                result.addChild(genericSig)
            }
            
            if isSerialized {
                result.addChild(createNode(.IsSerialized))
            }
            
            return result
        case "v":
            let Idx = demangleIndex()
            if Idx < 0 {
                return nil
            }
            return createNode(.OutlinedVariable, Idx)
        case "e":
            let Params = demangleBridgedMethodParams()
            if Params.isEmpty {
                return nil
            }
            return createNode(.OutlinedBridgedMethod, Params)
        case "u": return createNode(.AsyncFunctionPointer)
        case "U":
            guard let globalActor = popNode(.Type) else { return nil }
            
            guard let reabstraction = popNode() else { return nil }
            
            let node = createNode(.ReabstractionThunkHelperWithGlobalActor)
            node.addChild(reabstraction)
            node.addChild(globalActor)
            return node
        case "J":
            switch peekChar() {
            case "S":
                nextChar()
                return demangleAutoDiffSubsetParametersThunk()
            case "O":
                nextChar()
                return demangleAutoDiffSelfReorderingReabstractionThunk()
            case "V":
                nextChar()
                return demangleAutoDiffFunctionOrSimpleThunk(.AutoDiffDerivativeVTableThunk)
            default:
                return demangleAutoDiffFunctionOrSimpleThunk(.AutoDiffFunction)
            }
        default:
            return nil
        }
    }
    
    func demangleAutoDiffFunctionOrSimpleThunk(_ nodeKind: Node.Kind) -> Node? {
        var result: Node? = createNode(nodeKind)
        while let originalNode = popNode() {
            result = addChild(result, originalNode)
        }
        result.reverseChildren()
        let kind = demangleAutoDiffFunctionKind()
        result = addChild(result, kind)
        result = addChild(result, demangleIndexSubset())
        guard nextIf("p") else { return nil }
        result = addChild(result, demangleIndexSubset())
        guard nextIf("r") else { return nil }
        return result
    }
    
    func demangleAutoDiffFunctionKind() -> Node? {
        let kind = nextChar()
        if kind != "f" && kind != "r" && kind != "d" && kind != "p" {
            return nil
        }
        return createNode(.AutoDiffFunctionKind, kind)
    }
    
    func demangleAutoDiffSubsetParametersThunk() -> Node? {
        var result: Node? = createNode(.AutoDiffSubsetParametersThunk)
        while let node = popNode() {
            result = addChild(result, node)
        }
        result.reverseChildren()
        let kind = demangleAutoDiffFunctionKind()
        result = addChild(result, kind)
        result = addChild(result, demangleIndexSubset())
        guard nextIf("p") else { return nil }
        result = addChild(result, demangleIndexSubset())
        guard nextIf("r") else { return nil }
        result = addChild(result, demangleIndexSubset())
        guard nextIf("P") else { return nil }
        return result
    }
    
    func demangleAutoDiffSelfReorderingReabstractionThunk() -> Node? {
        var result: Node? = createNode(.AutoDiffSelfReorderingReabstractionThunk)
        addChild(result, popNode(.DependentGenericSignature))
        result = addChild(result, popNode(.Type))
        result = addChild(result, popNode(.Type))
        result.reverseChildren()
        result = addChild(result, demangleAutoDiffFunctionKind())
        return result
    }
    
    func demangleDifferentiabilityWitness() -> Node? {
        var result: Node? = createNode(.DifferentiabilityWitness)
        let optionalGenSig = popNode(.DependentGenericSignature)
        while let node = popNode() {
            result = addChild(result, node)
        }
        result?.reverseChildren()
        let kind: MangledDifferentiabilityKind
        let c = nextChar()
        switch c {
        case "f":
            kind = .forward
        case "r":
            kind = .reverse
        case "d":
            kind = .normal
        case "l":
            kind = .linear
        default:
            return nil
        }
        result = addChild(result, createNode(.Index, kind))
        result = addChild(result, demangleIndexSubset())
        if !nextIf("p") {
            return nil
        }
        result = addChild(result, demangleIndexSubset())
        if !nextIf("r") {
            return nil
        }
        addChild(result, optionalGenSig)
        return result
    }
    
    func demangleIndexSubset() -> Node? {
        var str = ""
        while peekChar() == "S" || peekChar() == "U" {
            str.append(peekChar())
            nextChar()
        }
        if str.isEmpty {
            return nil
        }
        return createNode(.IndexSubset, str)
    }
    
    func demangleDifferentiableFunctionType() -> Node? {
        let kind: MangledDifferentiabilityKind
        let c = nextChar()
        switch c {
        case "f":
            kind = .forward
        case "r":
            kind = .reverse
        case "d":
            kind = .normal
        case "l":
            kind = .linear
        default:
            return nil
        }
        return createNode(.DifferentiableFunctionType, kind)
    }
    
    func demangleBridgedMethodParams() -> String {
        if nextIf("_") {
            return ""
        }
        
        var Str = ""
        
        let kind = nextChar()
        switch kind {
        case "p", "a", "m":
            Str.append(kind)
        default:
            return ""
        }
        
        while !nextIf("_") {
            let c = nextChar()
            if c != "n" && c != "b" && c != "g" {
                return ""
            }
            Str.append(c)
        }
        return Str
    }
    
    func demangleGenericSpecialization(_ SpecKind: Node.Kind) -> Node? {
        guard let Spec = demangleSpecAttributes(SpecKind) else { return nil }
        guard let TyList = popTypeList() else { return nil }
        for Ty in TyList.copyOfChildren {
            Spec.addChild(createWithChild(.GenericSpecializationParam, Ty))
        }
        return Spec
    }
    
    func demangleFunctionSpecialization() -> Node? {
        var Spec = demangleSpecAttributes(.FunctionSignatureSpecialization)
        while Spec.hasValue, !nextIf("_") {
            Spec = addChild(Spec, demangleFuncSpecParam(.FunctionSignatureSpecializationParam))
        }
        if !nextIf("n") {
            Spec = addChild(Spec, demangleFuncSpecParam(.FunctionSignatureSpecializationReturn))
        }
        
        if !Spec {
            return nil
        }
        
        // Add the required parameters in reverse order.
        for Param in Spec?.copyOfChildren.reversed() ?? [] {
            var Param: Node? = Param
            if Param?.getKind() != .FunctionSignatureSpecializationParam {
                continue
            }
            
            if Param?.getNumChildren() == 0 {
                continue
            }
            let KindNd = Param?.getFirstChild()
            assert(KindNd?.getKind() == .FunctionSignatureSpecializationParamKind)
            let ParamKind = KindNd?.functionSigSpecializationParamKind
            switch ParamKind?.kind {
            case .ConstantPropFunction, .ConstantPropGlobal, .ConstantPropString, .ClosureProp:
                let FixedChildren = Param?.getNumChildren() ?? 0
                while let Ty = popNode(.Type) {
                    if ParamKind?.kind != .ClosureProp {
                        return nil
                    }
                    Param = addChild(Param, Ty)
                }
                guard let Name = popNode(.Identifier) else { return nil }
                var Text = Name.getText()
                if ParamKind?.kind == .ConstantPropString, !Text.isEmpty, Text[0] == "_" {
                    // A "_" escapes a leading digit or "_" of a string constant.
                    Text = Text.dropFirst().description
                }
                addChild(Param, createNodeWithAllocatedText(.FunctionSignatureSpecializationParamPayload, Text))
                Param?.reverseChildren(FixedChildren)
            default:
                break
            }
        }
        return Spec
    }
    
    func demangleFuncSpecParam(_ Kind: Node.Kind) -> Node? {
        assert(Kind == .FunctionSignatureSpecializationParam || Kind == .FunctionSignatureSpecializationReturn)
        let Param = createNode(Kind)
        switch nextChar() {
        case "n":
            return Param
        case "c":
            // Consumes an identifier and multiple type parameters.
            // The parameters will be added later.
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .ClosureProp))
        case "p":
            switch nextChar() {
            case "f":
                // Consumes an identifier parameter, which will be added later.
                return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .ConstantPropFunction))
            case "g":
                // Consumes an identifier parameter, which will be added later.
                return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .ConstantPropGlobal))
            case "i":
                return addFuncSpecParamNumber(Param, .ConstantPropInteger)
            case "d":
                return addFuncSpecParamNumber(Param, .ConstantPropFloat)
            case "s":
                // Consumes an identifier parameter (the string constant),
                // which will be added later.
                let Encoding: String
                switch nextChar() {
                case "b":
                    Encoding = "u8"
                case "w":
                    Encoding = "u16"
                case "c":
                    Encoding = "objc"
                default:
                    return nil
                }
                addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .ConstantPropString))
                return addChild(Param, createNode(.FunctionSignatureSpecializationParamPayload, Encoding))
            default:
                return nil
            }
            
        case "e":
            var Value = FunctionSigSpecializationParamKind.OptionSet.ExistentialToGeneric
            if nextIf("D") {
                Value.insert(.Dead)
            }
            if nextIf("G") {
                Value.insert(.OwnedToGuaranteed)
            }
            if nextIf("O") {
                Value.insert(.GuaranteedToOwned)
            }
            if nextIf("X") {
                Value.insert(.SROA)
            }
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, Value))
        case "d":
            var Value = FunctionSigSpecializationParamKind.OptionSet.Dead
            if nextIf("G") {
                Value.insert(.OwnedToGuaranteed)
            }
            if nextIf("O") {
                Value.insert(.GuaranteedToOwned)
            }
            if nextIf("X") {
                Value.insert(.SROA)
            }
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, Value))
        case "g":
            var Value = FunctionSigSpecializationParamKind.OptionSet.OwnedToGuaranteed
            if nextIf("X") {
                Value.insert(.SROA)
            }
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, Value))
        case "o":
            var Value = FunctionSigSpecializationParamKind.OptionSet.GuaranteedToOwned
            if nextIf("X") {
                Value.insert(.SROA)
            }
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, Value))
        case "x":
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .SROA))
        case "i":
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .BoxToValue))
        case "s":
            return addChild(Param, createNode(.FunctionSignatureSpecializationParamKind, .BoxToStack))
        default:
            return nil
        }
    }
    
    func demangleSpecAttributes(_ SpecKind: Node.Kind) -> Node? {
        let isSerialized = nextIf("q")
        
        let PassID = nextChar() - "0"
        guard (0...9).contains(PassID) else { return nil }
        
        let SpecNd = createNode(SpecKind)
        if isSerialized {
            SpecNd.addChild(createNode(.IsSerialized))
        }
        
        SpecNd.addChild(createNode(.SpecializationPassID, PassID))
        return SpecNd
    }
    
    func demangleWitness() -> Node? {
        let c = nextChar()
        switch c {
        case "C":
            return createWithChild(.EnumCase, popNode(isEntity))
        case "V":
            return createWithChild(.ValueWitnessTable, popNode(.Type))
        case "v":
            let Directness: Node.Directness
            switch nextChar() {
            case "d":
                Directness = .direct
            case "i":
                Directness = .indirect
            default:
                return nil
            }
            return createWithChildren(.FieldOffset, createNode(.Directness, Directness), popNode(isEntity))
        case "S":
            return createWithChild(.ProtocolSelfConformanceWitnessTable, popProtocol())
        case "P":
            return createWithChild(.ProtocolWitnessTable, popProtocolConformance())
        case "p":
            return createWithChild(.ProtocolWitnessTablePattern, popProtocolConformance())
        case "G":
            return createWithChild(.GenericProtocolWitnessTable, popProtocolConformance())
        case "I":
            return createWithChild(.GenericProtocolWitnessTableInstantiationFunction, popProtocolConformance())
        case "r":
            return createWithChild(.ResilientProtocolWitnessTable, popProtocolConformance())
        case "l":
            let Conf = popProtocolConformance()
            let Type = popNode(.Type)
            return createWithChildren(.LazyProtocolWitnessTableAccessor, Type, Conf)
        case "L":
            let Conf = popProtocolConformance()
            let Type = popNode(.Type)
            return createWithChildren(.LazyProtocolWitnessTableCacheVariable, Type, Conf)
        case "a":
            return createWithChild(.ProtocolWitnessTableAccessor, popProtocolConformance())
        case "t":
            let Name = popNode(isDeclName)
            let Conf = popProtocolConformance()
            return createWithChildren(.AssociatedTypeMetadataAccessor, Conf, Name)
        case "T":
            let ProtoTy = popNode(.Type)
            let ConformingType = popSelfOrAssocTypePath()
            let Conf = popProtocolConformance()
            return createWithChildren(.AssociatedTypeWitnessTableAccessor, Conf, ConformingType, ProtoTy)
        case "b":
            let ProtoTy = popNode(.Type)
            let Conf = popProtocolConformance()
            return createWithChildren(.BaseWitnessTableAccessor, Conf, ProtoTy)
        case "O":
            switch nextChar() {
            case "y":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedCopy, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedCopy, popNode(.Type))
            case "e":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedConsume, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedConsume, popNode(.Type))
            case "r":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedRetain, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedRetain, popNode(.Type))
            case "s":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedRelease, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedRelease, popNode(.Type))
            case "b":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedInitializeWithTake, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedInitializeWithTake, popNode(.Type))
            case "c":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedInitializeWithCopy, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedInitializeWithCopy, popNode(.Type))
            case "d":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedAssignWithTake, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedAssignWithTake, popNode(.Type))
            case "f":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedAssignWithCopy, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedAssignWithCopy, popNode(.Type))
            case "h":
                if let sig = popNode(.DependentGenericSignature) {
                    return createWithChildren(.OutlinedDestroy, popNode(.Type), sig)
                }
                return createWithChild(.OutlinedDestroy, popNode(.Type))
            default:
                return nil
            }
        case "Z", "z":
            let declList = createNode(.GlobalVariableOnceDeclList)
            var vars: [Node] = []
            while popNode(.FirstElementMarker).hasValue {
                guard let identifier = popNode(isDeclName) else { return nil }
                vars.append(identifier)
            }
            for node in vars {
                declList.addChild(node)
            }
            
            guard let context = popContext() else { return nil }
            let kind: Node.Kind = c == "Z" ? .GlobalVariableOnceFunction : .GlobalVariableOnceToken
            return createWithChildren(kind, context, declList)
        case "J":
            return demangleDifferentiabilityWitness()
        default:
            return nil
        }
    }
    
    func demangleSpecialType() -> Node? {
        let specialChar = nextChar()
        switch specialChar {
        case "E":
            return popFunctionType(.NoEscapeFunctionType)
        case "A":
            return popFunctionType(.EscapingAutoClosureType)
        case "f":
            return popFunctionType(.ThinFunctionType)
        case "K":
            return popFunctionType(.AutoClosureType)
        case "U":
            return popFunctionType(.UncurriedFunctionType)
        case "L":
            return popFunctionType(.EscapingObjCBlock)
        case "B":
            return popFunctionType(.ObjCBlock)
        case "C":
            return popFunctionType(.CFunctionPointer)
        case "z":
            let cchar = nextChar()
            switch cchar {
            case "B":
                return popFunctionType(.ObjCBlock, true)
            case "C":
                return popFunctionType(.CFunctionPointer, true)
            default:
                return nil
            }
        case "o":
            return createType(createWithChild(.Unowned, popNode(.Type)))
        case "u":
            return createType(createWithChild(.Unmanaged, popNode(.Type)))
        case "w":
            return createType(createWithChild(.Weak, popNode(.Type)))
        case "b":
            return createType(createWithChild(.SILBoxType, popNode(.Type)))
        case "D":
            return createType(createWithChild(.DynamicSelf, popNode(.Type)))
        case "M":
            let MTR = demangleMetatypeRepresentation()
            let Type = popNode(.Type)
            return createType(createWithChildren(.Metatype, MTR, Type))
        case "m":
            let MTR = demangleMetatypeRepresentation()
            let Type = popNode(.Type)
            return createType(createWithChildren(.ExistentialMetatype, MTR, Type))
        case "p":
            return createType(createWithChild(.ExistentialMetatype, popNode(.Type)))
        case "c":
            let Superclass = popNode(.Type)
            let Protocols = demangleProtocolList()
            return createType(createWithChildren(.ProtocolListWithClass, Protocols, Superclass))
        case "l":
            let Protocols = demangleProtocolList()
            return createType(createWithChild(.ProtocolListWithAnyObject, Protocols))
        case "X", "x":
            // SIL box types.
            var signature: Node?
            var genericArgs: Node?
            if specialChar == "X" {
                signature = popNode(.DependentGenericSignature)
                if signature == nil {
                    return nil
                }
                genericArgs = popTypeList()
                if genericArgs == nil {
                    return nil
                }
            }
            
            guard let fieldTypes = popTypeList() else { return nil }
            // Build layout.
            let layout = createNode(.SILBoxLayout)
            for i in 0..<fieldTypes.numberOfChildren {
                var fieldType: Node? = fieldTypes.getChild(i)
                assert(fieldType?.getKind() == .Type)
                var isMutable = false
                // 'inout' typelist mangling is used to represent mutable fields.
                if fieldType?.getChild(0).getKind() == .InOut {
                    isMutable = true
                    fieldType = createType(fieldType?.getChild(0).getChild(0))
                }
                let field = createNode(isMutable ? .SILBoxMutableField : .SILBoxImmutableField)
                field.addChild(fieldType)
                layout.addChild(field)
            }
            let boxTy = createNode(.SILBoxTypeWithLayout)
            boxTy.addChild(layout)
            if signature.hasValue {
                boxTy.addChild(signature)
                assert(genericArgs.hasValue)
                boxTy.addChild(genericArgs)
            }
            return createType(boxTy)
        case "Y":
            return demangleAnyGenericType(.OtherNominalType)
        case "Z":
            let types = popTypeList()
            let name = popNode(.Identifier)
            let parent = popContext()
            var anon: Node? = createNode(.AnonymousContext)
            anon = addChild(anon, name)
            anon = addChild(anon, parent)
            anon = addChild(anon, types)
            return anon
        case "e":
            return createType(createNode(.ErrorType))
        case "S":
            // Sugared type for debugger.
            switch nextChar() {
            case "q":
                return createType(createWithChild(.SugaredOptional, popNode(.Type)))
            case "a":
                return createType(createWithChild(.SugaredArray, popNode(.Type)))
            case "D":
                let value = popNode(.Type)
                let key = popNode(.Type)
                return createType(createWithChildren(.SugaredDictionary, key, value))
            case "p":
                return createType(createWithChild(.SugaredParen, popNode(.Type)))
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    func demangleMetatypeRepresentation() -> Node? {
        switch nextChar() {
        case "t":
            return createNode(.MetatypeRepresentation, "@thin")
        case "T":
            return createNode(.MetatypeRepresentation, "@thick")
        case "o":
            return createNode(.MetatypeRepresentation, "@objc_metatype")
        default:
            return nil
        }
    }
    
    func demangleAccessor(_ ChildNode: Node?) -> Node? {
        let Kind: Node.Kind
        switch nextChar() {
        case "m":
            Kind = .MaterializeForSet
        case "s":
            Kind = .Setter
        case "g":
            Kind = .Getter
        case "G":
            Kind = .GlobalGetter
        case "w":
            Kind = .WillSet
        case "W":
            Kind = .DidSet
        case "r":
            Kind = .ReadAccessor
        case "M":
            Kind = .ModifyAccessor
        case "a":
            switch nextChar() {
            case "O":
                Kind = .OwningMutableAddressor
            case "o":
                Kind = .NativeOwningMutableAddressor
            case "P":
                Kind = .NativePinningMutableAddressor
            case "u":
                Kind = .UnsafeMutableAddressor
            default:
                return nil
            }
        case "l":
            switch nextChar() {
            case "O":
                Kind = .OwningAddressor
            case "o":
                Kind = .NativeOwningAddressor
            case "p":
                Kind = .NativePinningAddressor
            case "u":
                Kind = .UnsafeAddressor
            default:
                return nil
            }
        case "p": // Pseudo-accessor referring to the variable/subscript itself
            return ChildNode
        default:
            return nil
        }
        let Entity = createWithChild(Kind, ChildNode)
        return Entity
    }
    
    enum Args {
        case None, TypeAndMaybePrivateName, TypeAndIndex, Index
    }
    
    func demangleFunctionEntity() -> Node? {
        let Args: Args
        
        var Kind = Node.Kind.EmptyList
        switch nextChar() {
        case "D":
            Args = .None
            Kind = .Deallocator
        case "d":
            Args = .None
            Kind = .Destructor
        case "E":
            Args = .None
            Kind = .IVarDestroyer
        case "e":
            Args = .None
            Kind = .IVarInitializer
        case "i":
            Args = .None
            Kind = .Initializer
        case "C":
            Args = .TypeAndMaybePrivateName
            Kind = .Allocator
        case "c":
            Args = .TypeAndMaybePrivateName
            Kind = .Constructor
        case "U":
            Args = .TypeAndIndex
            Kind = .ExplicitClosure
        case "u":
            Args = .TypeAndIndex
            Kind = .ImplicitClosure
        case "A":
            Args = .Index
            Kind = .DefaultArgumentInitializer
        case "p":
            return demangleEntity(.GenericTypeParamDecl)
        case "P":
            Args = .None
            Kind = .PropertyWrapperBackingInitializer
        case "W":
            Args = .None
            Kind = .PropertyWrapperInitFromProjectedValue
            break
        default:
            return nil
        }
        
        var NameOrIndex: Node?
        var ParamType: Node?
        var LabelList: Node?
        switch Args {
        case .None:
            break
        case .TypeAndMaybePrivateName:
            NameOrIndex = popNode(.PrivateDeclName)
            ParamType = popNode(.Type)
            LabelList = popFunctionParamLabels(ParamType)
        case .TypeAndIndex:
            NameOrIndex = demangleIndexAsNode()
            ParamType = popNode(.Type)
        case .Index:
            NameOrIndex = demangleIndexAsNode()
        }
        var Entity: Node? = createWithChild(Kind, popContext())
        switch Args {
        case .None:
            break
        case .Index:
            Entity = addChild(Entity, NameOrIndex)
        case .TypeAndMaybePrivateName:
            addChild(Entity, LabelList)
            Entity = addChild(Entity, ParamType)
            addChild(Entity, NameOrIndex)
        case .TypeAndIndex:
            Entity = addChild(Entity, NameOrIndex)
            Entity = addChild(Entity, ParamType)
        }
        return Entity
    }
    
    func demangleEntity(_ kind: Node.Kind) -> Node? {
        let Type = popNode(.Type)
        let LabelList = popFunctionParamLabels(Type)
        let Name = popNode(isDeclName)
        let Context = popContext()
        return LabelList.hasValue ? createWithChildren(kind, Context, Name, LabelList, Type) : createWithChildren(kind, Context, Name, Type)
    }
    
    func demangleVariable() -> Node? {
        let Variable = demangleEntity(.Variable)
        return demangleAccessor(Variable)
    }
    
    func demangleSubscript() -> Node? {
        let PrivateName = popNode(.PrivateDeclName)
        let Type = popNode(.Type)
        let LabelList = popFunctionParamLabels(Type)
        let Context = popContext()
        
        var Subscript: Node? = createNode(.Subscript)
        Subscript = addChild(Subscript, Context)
        addChild(Subscript, LabelList)
        Subscript = addChild(Subscript, Type)
        addChild(Subscript, PrivateName)
        
        return demangleAccessor(Subscript)
    }
    
    func demangleProtocolList() -> Node? {
        let TypeList = createNode(.TypeList)
        let ProtoList = createWithChild(.ProtocolList, TypeList)
        if !popNode(.EmptyList) {
            var firstElem = false
            repeat {
                firstElem = popNode(.FirstElementMarker).hasValue
                guard let Proto = popProtocol() else { return nil }
                TypeList.addChild(Proto)
            } while !firstElem
            
            TypeList.reverseChildren()
        }
        return ProtoList
    }
    
    func demangleProtocolListType() -> Node? {
        let ProtoList = demangleProtocolList()
        return createType(ProtoList)
    }
    
    func demangleGenericSignature(_ hasParamCounts: Bool) -> Node? {
        let Sig = createNode(.DependentGenericSignature)
        if hasParamCounts {
            while !nextIf("l") {
                var count = 0
                if !nextIf("z") {
                    count = demangleIndex() + 1
                }
                if count < 0 {
                    return nil
                }
                Sig.addChild(createNode(.DependentGenericParamCount, count))
            }
        } else {
            Sig.addChild(createNode(.DependentGenericParamCount, 1))
        }
        let NumCounts = Sig.getNumChildren()
        while let Req = popNode(isRequirement) {
            Sig.addChild(Req)
        }
        Sig.reverseChildren(NumCounts)
        return Sig
    }
    
    enum TypeKind { case Generic, Assoc, CompoundAssoc, Substitution }
    enum ConstraintKind { case `Protocol`, BaseClass, SameType, Layout }
    
    func demangleGenericRequirement() -> Node? {
        
        let TypeKind: TypeKind
        let ConstraintKind: ConstraintKind
        
        switch nextChar() {
        case "c":
            ConstraintKind = .BaseClass
            TypeKind = .Assoc
        case "C":
            ConstraintKind = .BaseClass
            TypeKind = .CompoundAssoc
        case "b":
            ConstraintKind = .BaseClass
            TypeKind = .Generic
        case "B":
            ConstraintKind = .BaseClass
            TypeKind = .Substitution
        case "t":
            ConstraintKind = .SameType
            TypeKind = .Assoc
        case "T":
            ConstraintKind = .SameType
            TypeKind = .CompoundAssoc
        case "s":
            ConstraintKind = .SameType
            TypeKind = .Generic
        case "S":
            ConstraintKind = .SameType
            TypeKind = .Substitution
        case "m":
            ConstraintKind = .Layout
            TypeKind = .Assoc
        case "M":
            ConstraintKind = .Layout
            TypeKind = .CompoundAssoc
        case "l":
            ConstraintKind = .Layout
            TypeKind = .Generic
        case "L":
            ConstraintKind = .Layout
            TypeKind = .Substitution
        case "p":
            ConstraintKind = .Protocol
            TypeKind = .Assoc
        case "P":
            ConstraintKind = .Protocol
            TypeKind = .CompoundAssoc
        case "Q":
            ConstraintKind = .Protocol
            TypeKind = .Substitution
        default:
            ConstraintKind = .Protocol
            TypeKind = .Generic
            pushBack()
        }
        
        let ConstrTy: Node?
        
        switch TypeKind {
        case .Generic:
            ConstrTy = createType(demangleGenericParamIndex())
        case .Assoc:
            ConstrTy = demangleAssociatedTypeSimple(demangleGenericParamIndex())
            addSubstitution(ConstrTy)
        case .CompoundAssoc:
            ConstrTy = demangleAssociatedTypeCompound(demangleGenericParamIndex())
            addSubstitution(ConstrTy)
        case .Substitution:
            ConstrTy = popNode(.Type)
        }
        
        switch ConstraintKind {
        case .Protocol:
            return createWithChildren(.DependentGenericConformanceRequirement, ConstrTy, popProtocol())
        case .BaseClass:
            return createWithChildren(.DependentGenericConformanceRequirement, ConstrTy, popNode(.Type))
        case .SameType:
            return createWithChildren(.DependentGenericSameTypeRequirement, ConstrTy, popNode(.Type))
        case .Layout:
            let c = nextChar()
            var size: Node?
            var alignment: Node?
            let name: String
            if (c == "U") {
                name = "U"
            } else if (c == "R") {
                name = "R"
            } else if (c == "N") {
                name = "N"
            } else if (c == "C") {
                name = "C"
            } else if (c == "D") {
                name = "D"
            } else if (c == "T") {
                name = "T"
            } else if (c == "E") {
                size = demangleIndexAsNode()
                if size == nil {
                    return nil
                }
                alignment = demangleIndexAsNode()
                name = "E"
            } else if (c == "e") {
                size = demangleIndexAsNode()
                if size == nil {
                    return nil
                }
                name = "e"
            } else if (c == "M") {
                size = demangleIndexAsNode()
                if size == nil {
                    return nil
                }
                alignment = demangleIndexAsNode()
                name = "M"
            } else if (c == "m") {
                size = demangleIndexAsNode()
                if size == nil {
                    return nil
                }
                name = "m"
            } else {
                // Unknown layout constraint.
                return nil
            }
            
            let NameNode = createNode(.Identifier, name)
            let LayoutRequirement = createWithChildren(.DependentGenericLayoutRequirement, ConstrTy, NameNode)
            if let size = size {
                addChild(LayoutRequirement, size)
            }
            if let alignment = alignment {
                addChild(LayoutRequirement, alignment)
            }
            return LayoutRequirement
            
        }
    }
    
    func demangleGenericType() -> Node? {
        let GenSig = popNode(.DependentGenericSignature)
        let Ty = popNode(.Type)
        return createType(createWithChildren(.DependentGenericType, GenSig, Ty))
    }
    
    func demangleValueWitness() -> Node? {
        var Code = ""
        Code.append(nextChar())
        Code.append(nextChar())
        guard let kind = decodeValueWitnessKind(Code) else { return nil }
        let VW = createNode(.ValueWitness)
        addChild(VW, createNode(.Index, kind))
        return addChild(VW, popNode(.Type))
    }
    
    func decodeValueWitnessKind(_ CodeStr: String) -> Node.ValueWitnessKind? {
        return Node.ValueWitnessKind(code: CodeStr)
    }
    
    @discardableResult
    func nextIf(_ str: String) -> Bool {
        guard mangled.hasPrefix(str) else { return false }
        mangled = Data(mangled.dropFirst(str.count))
        return true
    }
    
    func peekChar() -> Character {
        guard mangled.isNotEmpty else { return .zero }
        return mangled[0].character
    }
    
    @discardableResult
    func nextChar() -> Character {
        guard let first = mangled.first else { return .zero }
        mangled = Data(mangled.dropFirst())
        return first.character
    }
    
    func nextIf(_ c: Character) -> Bool {
        guard peekChar() == c else { return false }
        nextChar()
        return true
    }
    
    func pushBack() {
        assert(mangled.count < mangledOriginal.count)
        mangled.insert(mangledOriginal[mangledOriginal.count - mangled.count - 1], at: mangled.startIndex)
    }
    
    func consumeAll() -> String {
        defer {
            mangled = Data()
        }
        return String(data: mangled, encoding: .ascii) ?? ""
    }
    
    func addSubstitution(_ node: Node?) {
        guard let node = node else { return }
        substitutions.append(node)
    }
    
    func pushMultiSubstitutions(_ RepeatCount: Int, _ SubstIdx: Int) -> Node? {
        if SubstIdx >= substitutions.size() {
            return nil
        }
        if RepeatCount > maxRepeatCount {
            return nil
        }
        let Nd = substitutions[SubstIdx]
        if RepeatCount > 1 {
            for _ in 0..<RepeatCount - 1 {
                pushNode(Nd)
            }
        }
        return Nd
    }
    
    func getDependentGenericParamType(_ depth: Int, _ index: Int) -> Node? {
        guard depth >= 0, index >= 0 else { return nil }
        
        let paramTy = createNode(.DependentGenericParamType)
        paramTy.addChild(createNode(.Index, depth))
        paramTy.addChild(createNode(.Index, index))
        return paramTy
    }
    
    func pushNode(_ node: Node) {
        nodeStack.append(node)
    }
    
    func nodeConsumesGenericArgs(_ node: Node) -> Bool {
        switch node.getKind() {
        case .Variable, .Subscript, .ImplicitClosure, .ExplicitClosure, .DefaultArgumentInitializer, .Initializer, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue:
            return false
        default:
            return true
        }
    }
    
    func popNode() -> Node? {
        guard nodeStack.isNotEmpty else { return nil }
        return nodeStack.removeLast()
    }
    
    func popNode(_ kind: Node.Kind) -> Node? {
        guard nodeStack.isNotEmpty else { return nil }

        if let lastKind = nodeStack.last?.kind {
            if lastKind != kind {
                return nil
            } else {
                return popNode()
            }
        } else {
            return nil
        }
    }
    
    func popNode(_ pred: (Node.Kind) -> Bool) -> Node? {
        guard nodeStack.isNotEmpty else { return nil }
        if let kind = nodeStack.last?.kind {
            if !pred(kind) {
                return nil
            } else {
                return popNode()
            }
        } else {
            return nil
        }
    }
    
    func popNode(_ keyPath: KeyPath<Node.Kind, Bool>) -> Node? {
        guard nodeStack.isNotEmpty else { return nil }
        
        if let kind = nodeStack.last?.kind {
            if !kind[keyPath: keyPath] {
                return nil
            } else {
                return popNode()
            }
        } else {
            return nil
        }
    }
    
    func popModule() -> Node? {
        if let Ident = popNode(.Identifier) {
            return changeKind(Ident, .Module)
        }
        return popNode(.Module)
    }
    
    func popContext() -> Node? {
        if let mod = popModule() {
            return mod
        }
        if let Ty = popNode(.Type) {
            if Ty.getNumChildren() != 1 {
                return nil
            }
            
            let Child = Ty.getFirstChild()
            if !Child.getKind().isContext {
                return nil
            }
            return Child
        }
        return popNode(isContext)
    }
    
    func popTypeAndGetChild() -> Node? {
        guard let Ty = popNode(.Type), Ty.numberOfChildren == 1 else { return nil }
        return Ty.getFirstChild()
    }
    
    func popTypeAndGetAnyGeneric() -> Node? {
        if let child = popTypeAndGetChild(), child.getKind().isAnyGeneric {
            return child
        }
        return nil
    }
    
    func popFunctionType(_ kind: Node.Kind, _ hasClangType: Bool = false) -> Node? {
        var FuncType: Node? = createNode(kind)
        var ClangType: Node?
        if hasClangType {
            ClangType = demangleClangType()
        }
        addChild(FuncType, ClangType)
        addChild(FuncType, popNode(.GlobalActorFunctionType))
        addChild(FuncType, popNode(.DifferentiableFunctionType))
        addChild(FuncType, popNode(.ThrowsAnnotation))
        addChild(FuncType, popNode(.ConcurrentFunctionType))
        addChild(FuncType, popNode(.AsyncAnnotation))
        
        FuncType = addChild(FuncType, popFunctionParams(.ArgumentTuple))
        FuncType = addChild(FuncType, popFunctionParams(.ReturnType))
        return createType(FuncType)
    }
    
    func popFunctionParams(_ kind: Node.Kind) -> Node? {
        var ParamsType: Node?
        if popNode(.EmptyList) != nil {
            ParamsType = createType(createNode(.Tuple))
        } else {
            ParamsType = popNode(.Type)
        }
        return createWithChild(kind, ParamsType)
    }
    
    func popFunctionParamLabels(_ Type: Node?) -> Node? {
        if !IsOldFunctionTypeMangling, popNode(.EmptyList).hasValue {
            return createNode(.LabelList)
        }
        
        guard let Type = Type, Type.getKind() == .Type else { return nil }
        
        var FuncType = Type.getFirstChild()
        if FuncType.getKind() == .DependentGenericType {
            FuncType = FuncType.getChild(1).getFirstChild()
        }
        
        if FuncType.getKind() != .FunctionType && FuncType.getKind() != .NoEscapeFunctionType {
            return nil
        }
        
        var FirstChildIdx = 0
        if FuncType.getChild(FirstChildIdx).getKind() == .GlobalActorFunctionType {
            ++FirstChildIdx
        }
        if FuncType.getChild(FirstChildIdx).getKind() == .DifferentiableFunctionType {
            ++FirstChildIdx
        }
        if FuncType.getChild(FirstChildIdx).getKind() == .ThrowsAnnotation {
            ++FirstChildIdx
        }
        if FuncType.getChild(FirstChildIdx).getKind() == .ConcurrentFunctionType {
            ++FirstChildIdx
        }
        if FuncType.getChild(FirstChildIdx).getKind() == .AsyncAnnotation {
            ++FirstChildIdx
        }
        let ParameterType = FuncType.getChild(FirstChildIdx)
        
        assert(ParameterType.getKind() == .ArgumentTuple)
        
        let ParamsType = ParameterType.getFirstChild()
        assert(ParamsType.getKind() == .Type)
        let Params = ParamsType.getFirstChild()
        let NumParams = Params.getKind() == .Tuple ? Params.getNumChildren() : 1
        
        if NumParams == 0 {
            return nil
        }
        
        func getChildIf(_ node: Node, _ filterBy: Node.Kind) -> (offset: Int, element: Node)? {
            for node in node.copyOfChildren.enumerated() {
                if node.element.getKind() == filterBy {
                    return node
                }
            }
            return nil
        }
        
        func getLabel(_ Params: Node, _ Idx: Int) -> Node? {
            // Old-style function type mangling has labels as part of the argument.
            if IsOldFunctionTypeMangling {
                let Param = Params.getChild(Idx)
                if let Label = getChildIf(Param, .TupleElementName) {
                    Param.removeChildAt(Label.offset)
                    return createNodeWithAllocatedText(.Identifier, Label.element.getText())
                }
                
                return createNode(.FirstElementMarker)
            }
            
            return popNode()
        }
        
        let LabelList = createNode(.LabelList)
        let Tuple = ParameterType.getFirstChild().getFirstChild()
        
        if IsOldFunctionTypeMangling && Tuple.getKind() != .Tuple {
            return LabelList
        }
        
        var hasLabels = false
        for i in 0..<NumParams {
            guard let Label = getLabel(Tuple, i) else { return nil }
            
            if Label.getKind() != .Identifier && Label.getKind() != .FirstElementMarker {
                return nil
            }
            
            LabelList.addChild(Label)
            hasLabels = hasLabels || Label.getKind() != .FirstElementMarker
        }
        
        // Old style label mangling can produce label list without
        // actual labels, we need to support that case specifically.
        if !hasLabels {
            return createNode(.LabelList)
        }
        
        if !IsOldFunctionTypeMangling {
            LabelList.reverseChildren()
        }
        
        return LabelList
    }
    
    func popTuple() -> Node? {
        let Root = createNode(.Tuple)
        
        if !popNode(.EmptyList) {
            var firstElem = false
            repeat {
                firstElem = popNode(.FirstElementMarker).hasValue
                let TupleElmt = createNode(.TupleElement)
                addChild(TupleElmt, popNode(.VariadicMarker))
                if let Ident = popNode(.Identifier) {
                    TupleElmt.addChild(createNodeWithAllocatedText(.TupleElementName, Ident.getText()))
                }
                guard let Ty = popNode(.Type) else { return nil }
                TupleElmt.addChild(Ty)
                Root.addChild(TupleElmt)
            } while !firstElem
            
            Root.reverseChildren()
        }
        return createType(Root)
    }
    
    func popTypeList() -> Node? {
        let Root = createNode(.TypeList)
        
        if !popNode(.EmptyList) {
            var firstElem = false
            repeat {
                firstElem = popNode(.FirstElementMarker).hasValue
                guard let Ty = popNode(.Type) else { return nil }
                Root.addChild(Ty)
            } while !firstElem
            
            Root.reverseChildren()
        }
        return Root
    }
    
    func popProtocol() -> Node? {
        if let type = popNode(.Type) {
            guard type.numberOfChildren > 0 else { return nil }
            
            guard type.isProtocol else { return nil }
            
            return type
        }
        
        if let  symbolicRef = popNode(.ProtocolSymbolicReference) {
            return symbolicRef
        }
        
        let Name = popNode(isDeclName)
        let Ctx = popContext()
        let Proto = createWithChildren(.Protocol, Ctx, Name)
        return createType(Proto)
    }
    
    func popAnyProtocolConformanceList() -> Node? {
        let conformanceList = createNode(.AnyProtocolConformanceList)
        if popNode(.EmptyList) == nil {
            var firstElem = false
            repeat {
                firstElem = popNode(.FirstElementMarker).hasValue
                guard let anyConformance = popAnyProtocolConformance() else { return nil }
                conformanceList.addChild(anyConformance)
            } while !firstElem
            
            conformanceList.reverseChildren()
        }
        return conformanceList
    }
    
    func popAnyProtocolConformance() -> Node? {
        return popNode({ kind in
            switch (kind) {
            case .ConcreteProtocolConformance, .DependentProtocolConformanceRoot, .DependentProtocolConformanceInherited, .DependentProtocolConformanceAssociated:
                return true
            default:
                return false
            }
        })
    }
    
    
    func popDependentProtocolConformance() -> Node? {
        return popNode({ kind in
            switch (kind) {
            case .DependentProtocolConformanceRoot, .DependentProtocolConformanceInherited, .DependentProtocolConformanceAssociated:
                return true
            default:
                return false
            }
        })
    }
    
    
    func popDependentAssociatedConformance() -> Node? {
        let proto = popProtocol()
        let dependentType = popNode(.Type)
        return createWithChildren(.DependentAssociatedConformance, dependentType, proto)
    }
    
    func popAssocTypeName() -> Node? {
        var proto = popNode(.Type)
        if proto != nil && !proto.isProtocol {
            return nil
        }
        
        // If we haven't seen a protocol, check for a symbolic reference.
        if proto == nil {
            proto = popNode(.ProtocolSymbolicReference)
        }
        
        let identifier = popNode(.Identifier)
        let assocTy = createWithChild(.DependentAssociatedTypeRef, identifier)
        addChild(assocTy, proto)
        return assocTy
    }
    
    func popAssocTypePath() -> Node? {
        let assocTypePath = createNode(.AssocTypePath)
        var firstElem = false
        repeat {
            firstElem = popNode(.FirstElementMarker) != nil
            guard let assocTy = popAssocTypeName() else { return nil }
            assocTypePath.add(assocTy)
        } while !firstElem
        assocTypePath.reverseChildren()
        return assocTypePath
    }
    
    func popSelfOrAssocTypePath() -> Node? {
        if let Type = popNode(.Type) {
            if let child = Type.copyOfChildren.first, child.getKind() == .DependentGenericParamType {
                return Type
            }
            
            pushNode(Type)
        }
        
        return popAssocTypePath()
    }
    
    func popProtocolConformance() -> Node? {
        let genSig = popNode(.DependentGenericSignature)
        let module = popModule()
        let proto = popProtocol()
        var type = popNode(.Type)
        var ident: Node?
        if type == nil {
            // Property behavior conformance
            ident = popNode(.Identifier)
            type = popNode(.Type)
        }
        if genSig != nil {
            type = createType(createWithChildren(.DependentGenericType, genSig, type))
        }
        let conf = createWithChildren(.ProtocolConformance, type, proto, module)
        addChild(conf, ident)
        return conf
    }
    
    @discardableResult
    func addChild(_ parent: Node?, _ child: Node?) -> Node? {
        guard let parent = parent, let child = child else { return nil }
        return parent.adding(child)
    }
    
    func createNode(_ kind: Node.Kind) -> Node {
        Node(kind)
    }
    
    func createNode<N>(_ kind: Node.Kind, _ index: N) -> Node where N: BinaryInteger{
        Node(kind, index)
    }
    
    func createNode(_ kind: Node.Kind, _ text: String) -> Node {
        Node(kind: kind, text: text)
    }
    
    func createNode(_ kind: Node.Kind, _ character: Character) -> Node {
        Node(kind: kind, text: character.description)
    }
    
    func createNode(_ kind: Node.Kind, _ directness: Node.Directness) -> Node {
        Node(kind: kind, payload: .directness(directness))
    }
    
    func createNode(_ kind: Node.Kind, _ valueWitnessKind: Node.ValueWitnessKind) -> Node {
        Node(kind, .valueWitnessKind(valueWitnessKind))
    }
    
    func createNode(_ kind: Node.Kind, _ functionSigSpecializationParamKind: FunctionSigSpecializationParamKind) -> Node {
        Node(kind, .functionSigSpecializationParamKind(functionSigSpecializationParamKind))
    }
    
    func createNode(_ kind: Node.Kind, _ functionSigSpecializationParamKindKind: FunctionSigSpecializationParamKind.Kind) -> Node {
        Node(kind, .functionSigSpecializationParamKind(functionSigSpecializationParamKindKind.createFunctionSigSpecializationParamKind()))
    }
    
    func createNode(_ kind: Node.Kind, _ functionSigSpecializationParamKindOption: FunctionSigSpecializationParamKind.OptionSet) -> Node {
        Node(kind, .functionSigSpecializationParamKind(functionSigSpecializationParamKindOption.createFunctionSigSpecializationParamKind()))
    }
    
    func createNode(_ kind: Node.Kind, _ mangledDifferentiabilityKind: MangledDifferentiabilityKind) -> Node {
        Node(kind: kind, payload: .mangledDifferentiabilityKind(mangledDifferentiabilityKind))
    }
    
    func createWithChild(_ kind: Node.Kind, _ child: Node?) -> Node? {
        guard let child = child else { return nil }
        return createNode(kind).adding(child)
    }
    
    func createNodeWithAllocatedText(_ kind: Node.Kind, _ text: String) -> Node? {
        Node(kind: kind, text: text)
    }
    
    func createType(_ child: Node?) -> Node? {
        createWithChild(.Type, child)
    }
    
    func createWithChildren(_ kind: Node.Kind, _ children: Node?...) -> Node? {
        let flatten = children.flatten()
        guard flatten.count == children.count else { return nil }
        return createNode(kind).adding(flatten)
    }
    
    func createSwiftType(_ typeKind: Node.Kind, _ name: String) -> Node? {
        return createType(createWithChildren(typeKind, Node(.Module, .text(.STDLIB_NAME)), Node(.Identifier, .text(name))))
    }
    
    func createStandardSubstitution(_ Subst: Character, _ SecondLevel: Bool) -> Node? {
        if !SecondLevel {
            for st in StandardType.allCases where st.rawValue == Subst {
                return createSwiftType(st.kind, st.typeName)
            }
        }
        if SecondLevel {
            for st in StandardTypeConcurrency.allCases where st.rawValue == Subst {
                return createSwiftType(st.kind, st.typeName)
            }
        }
        return nil
    }
    
    func createWithPoppedType(_ kind: Node.Kind) -> Node? {
        return createWithChild(kind, popNode(.Type))
    }
    
    func changeKind(_ node: Node?, _ newKind: Node.Kind) -> Node? {
        guard let node = node else { return nil }
        let newNode: Node
        if node.hasText {
            newNode = Node(newKind, .text(node.text))
        } else if let index = node.index {
            newNode = Node(newKind, index)
        } else {
            newNode = Node(newKind)
        }
        newNode.adds(node.copyOfChildren)
        return newNode
    }
    
    func addFuncSpecParamNumber(_ Param: Node?, _ Kind: FunctionSigSpecializationParamKind.Kind) -> Node? {
        addFuncSpecParamNumber(Param, Kind.createFunctionSigSpecializationParamKind())
    }
    
    func addFuncSpecParamNumber(_ Param: Node?, _ Kind: FunctionSigSpecializationParamKind) -> Node? {
        Param?.addChild(createNode(.FunctionSignatureSpecializationParamKind, Kind))
        var str = ""
        while peekChar().isDigit {
            str.append(nextChar())
        }
        if str.isEmpty {
            return nil
        }
        return addChild(Param, createNode(.FunctionSignatureSpecializationParamPayload, str))
    }
    
    func isDeclName(_ kind: Node.Kind) -> Bool {
        kind.isDeclName
    }
    
    func isContext(_ kind: Node.Kind) -> Bool {
        kind.isContext
    }
    
    func isRequirement(_ kind: Node.Kind) -> Bool {
        kind.isRequirement
    }
    
    func isEntity(_ kind: Node.Kind) -> Bool {
        kind.isEntity
    }
    
    func isFunctionAttr(_ kind: Node.Kind) -> Bool {
        kind.isFunctionAttr
    }
}

extension Node {
    func addChild(_ node: Node?) {
        node.flatMap(self.add)
    }
    func getText() -> String {
        text
    }
    func getKind() -> Node.Kind {
        kind
    }
    func getFirstChild() -> Node {
        firstChild
    }
    func getChild(_ at: Int) -> Node {
        children(at)
    }
    func getChildOrNil(_ at: Int) -> Node? {
        if at < numberOfChildren {
            return children(at)
        } else {
            return nil
        }
    }
    func getNumChildren() -> Int {
        numberOfChildren
    }
    func removeChildAt(_ at: Int) {
        self.remove(at)
    }
}

private prefix func --<N>(_ rhs: inout N) where N: BinaryInteger {
    rhs = rhs.advanced(by: -1)
}

private prefix func ++<N>(_ rhs: inout N) where N: BinaryInteger {
    rhs = rhs.advanced(by: 1)
}

private extension Optional where Wrapped == Node {
    func reverseChildren() {
        self?.reverseChildren()
    }
    
    func getKind() -> Node.Kind? {
        self?.kind
    }
    
    func add(_ node: Node?) {
        self?.add(node)
    }
    
    func addChild(_ node: Node?) {
        self?.add(node)
    }
    
    func adds<S>(_ nodes: S) where S: Sequence, S.Element == Node? {
        self.adds(nodes.compactMap({ $0 }))
    }
    
    func adds<C>(_ nodes: C) where C: Collection, C.Element == Node {
        self?.adds(nodes)
    }
    
    func getChild(_ at: Int) -> Node? {
        self?.getChild(at)
    }
    
    func getNumChildren() -> Int {
        self?.getNumChildren() ?? 0
    }
    
    func getText() -> String {
        self?.getText() ?? ""
    }
}

private extension Array where Element == Node {
    mutating func append(_ node: Node?) {
        guard let node = node else { return }
        self.append(node)
    }
    
    mutating func push_back(_ node: Node) {
        self.append(node)
    }
    
    func size() -> Int { count }
}

private extension String {
    func empty() -> Bool { isEmpty }
    func size() -> Int { count }
    
    func substr(_ from: Int) -> String {
        guard from < self.count else { return "" }
        return String(self[from..<self.count])
    }
    
    mutating func push_back(_ character: Character) {
        self.append(character)
    }
}

private extension Data {
    func empty() -> Bool { isEmpty }
    func size() -> Int { count }
    
    func hasPrefix(_ str: String) -> Bool {
        guard let strData = str.data(using: .ascii) else { return false }
        guard strData.count <= self.count else { return false }
        return strData == self[0..<strData.count]
    }
    
    func substr(_ from: Int) -> String {
        guard from < self.count else { return "" }
        return String(data: self[from..<self.count], encoding: .ascii) ?? ""
    }
    
    mutating func push_back(_ character: Character) {
        guard let value = character.asciiValue else { return }
        self.append(value)
    }
}

extension UInt8 {
    var character: Character { Character(.init(self)) }
}

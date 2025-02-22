//
//  Node.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/26.
//

import Foundation

final class Node {
    
    typealias IndexType = UInt64
    
    private weak var parent: Node?
    
    public private(set) var kind: Kind
    private(set) var payload: Payload
    public private(set) var _children: [Node] {
        didSet {
            _children.forEach({ $0.parent = self })
        }
    }
    
    var copyOfChildren: [Node] { _children }
    
    fileprivate var numberOfParent: Int {
        var count = 0
        var parent: Node? = self.parent
        while parent != nil {
            count += 1
            parent = parent?.parent
        }
        return count
    }
    
    var numberOfChildren: Int { _children.count }
    
    init(kind: Kind) {
        self.kind = kind
        self.payload = .none
        self._children = []
    }
    
    convenience init(_ kind: Kind) {
        self.init(kind: kind)
    }
    
    init(kind: Kind, text: String) {
        self.kind = kind
        self.payload = .text(text)
        self._children = []
    }
    
    convenience init(_ kind: Kind, _ character: Character) {
        self.init(kind: kind, text: character.description)
    }
    
    init(kind: Kind, functionParamKind: FunctionSigSpecializationParamKind.Kind) {
        self.kind = kind
        self.payload = .functionSigSpecializationParamKind(.init(kind: functionParamKind))
        self._children = []
    }
    
    init(kind: Kind, functionParamOption: FunctionSigSpecializationParamKind.OptionSet) {
        self.kind = kind
        self.payload = .functionSigSpecializationParamKind(.init(optionSet: functionParamOption))
        self._children = []
    }
    
    init<N>(kind: Kind, index: N) where N: BinaryInteger {
        self.kind = kind
        self.payload = .index(UInt64(index))
        self._children = []
    }
    
    convenience init<N>(_ kind: Kind, _ index: N) where N: BinaryInteger {
        self.init(kind: kind, index: index)
    }
    
    init(kind: Kind, payload: Payload) {
        self.kind = kind
        self.payload = payload
        self._children = []
    }
    
    convenience init(_ kind: Kind, _ payload: Payload) {
        self.init(kind: kind, payload: payload)
    }
    
    init(kind: Kind, children: Node?...) {
        self.kind = kind
        self.payload = .none
        self._children = children.flatten()
        self.updatePayloadForChildren()
    }
    
    convenience init(kind: Kind, child: Node?) {
        self.init(kind: kind, children: child)
    }
    
    func newNode(_ kind: Kind) -> Node {
        let node = Node(kind: kind)
        node.payload = payload
        node._children = _children
        return node
    }
    
    func children(_ at: Int) -> Node {
        if at < self._children.count {
            return self._children[at]
        } else {
            assertionFailure()
            return Node(kind: .UnknownIndex)
        }
    }
    
    func childIf(_ kind: Node.Kind) -> Node? {
        _children.first(where: { $0.kind == kind })
    }
    
    private func updatePayloadForChildren() {
        switch self._children.count {
        case 1:
            payload = .onechild
        case 2:
            payload = .twochildren
        case 3...:
            payload = .manychildren
        default:
            payload = .none
        }
    }
    
    func add(_ child: Node) {
        if payload.isChildren {
            self._children.append(child)
            self.updatePayloadForChildren()
        } else {
            assertionFailure("cannot add child to \(self)")
        }
    }
    
    func add(_ childOrNil: Node?) {
        guard let child = childOrNil else { return }
        self.add(child)
    }
    
    func add(_ kind: Node.Kind) {
        add(.init(kind: kind))
    }
    
    func add(kind: Node.Kind, text: String) {
        add(.init(kind: kind, text: text))
    }
    
    func add(kind: Node.Kind, payload: Payload) {
        add(Node(kind: kind, payload: payload))
    }
    
    func adds<C>(_ children: C) where C: Collection, C.Element == Node {
        guard children.isNotEmpty else { return }
        if payload.isChildren {
            self._children.append(contentsOf: children)
            self.updatePayloadForChildren()
        } else {
            assertionFailure("cannot add child to \(self)")
        }
    }
    
    func addFunctionSigSpecializationParamKind(kind: FunctionSigSpecializationParamKind.Kind, texts: String...) {
        add(Node(kind: .FunctionSignatureSpecializationParamKind, functionParamKind: kind))
        for text in texts {
            add(Node(kind: .FunctionSignatureSpecializationParamPayload, text: text))
        }
    }
    
    func adding(_ children: Node?...) -> Self {
        self.adding(children.flatten())
    }
    
    func adding(_ children: [Node]) -> Self {
        self.adds(children)
        return self
    }
    
    func remove(_ child: Node) {
        if let index = _children.firstIndex(where: { $0 === child }) {
            self._children.remove(at: index)
        }
    }
    
    func remove(_ at: Int) {
        guard at < numberOfChildren else { return }
        self._children.remove(at: at)
    }
    
    func reverseChildren() {
        _children.reverse()
    }
    
    func reverseChildren(_ fromAt: Int) {
        guard fromAt < numberOfChildren else { return }
        if fromAt == 0 {
            _children.reverse()
        } else {
            let prefix = _children[0..<fromAt]
            let reversedSuffix = _children[fromAt..<_children.count].reversed()
            self._children = Array(prefix) + reversedSuffix
        }
    }
    
    func replaceLast(_ child: Node) {
        self._children.removeLast()
        self._children.append(child)
    }
    
    var isSwiftModule: Bool {
        kind == .Module && text == .STDLIB_NAME
    }
    
    func isIdentifier(desired: String) -> Bool {
        kind == .Identifier && text == desired
    }
    
    public var text: String {
        if case let .text(text) = self.payload {
            return text
        } else {
            return ""
        }
    }
    
    var hasText: Bool {
        self.payload.isText
    }
    
    var index: UInt64? {
        switch self.payload {
        case let .index(index):
            return index
        default:
            return nil
        }
    }
    
    var functionSigSpecializationParamKind: FunctionSigSpecializationParamKind? {
        switch self.payload {
        case let .functionSigSpecializationParamKind(kind):
            return kind
        default:
            return nil
        }
    }
    
    var valueWitnessKind: ValueWitnessKind? {
        switch self.payload {
        case let .valueWitnessKind(w):
            return w
        default:
            return nil
        }
    }
    
    var mangledDifferentiabilityKind: MangledDifferentiabilityKind? {
        switch self.payload {
        case let .mangledDifferentiabilityKind(kind):
            return kind
        case let .text(text):
            return MangledDifferentiabilityKind(rawValue: text)
        default:
            return nil
        }
    }
    
    var firstChild: Node {
        children(0)
    }
    
    var lastChild: Node {
        children(_children.endIndex - 1)
    }
    
    var directness: Directness {
        if case let .directness(directness) = self.payload {
            return directness
        } else {
            assertionFailure()
            return .unknown
        }
    }
}

// MARK: Type
extension Node {
    var isNeedSpaceBeforeType: Bool {
        switch kind {
        case .Type:
            return firstChild.isNeedSpaceBeforeType
        case .FunctionType,
             .NoEscapeFunctionType,
             .UncurriedFunctionType,
             .DependentGenericType:
            return false
        default:
            return true
        }
    }
    var isSimpleType: Bool {
        switch kind {
        case .AssociatedType,
             .AssociatedTypeRef,
             .BoundGenericClass,
             .BoundGenericEnum,
             .BoundGenericStructure,
             .BoundGenericProtocol,
             .BoundGenericOtherNominalType,
             .BoundGenericTypeAlias,
             .BoundGenericFunction,
             .BuiltinTypeName,
             .Class,
             .DependentGenericType,
             .DependentMemberType,
             .DependentGenericParamType,
             .DynamicSelf,
             .Enum,
             .ErrorType,
             .ExistentialMetatype,
             .Metatype,
             .MetatypeRepresentation,
             .Module,
             .Tuple,
             .Protocol,
             .ProtocolSymbolicReference,
             .ReturnType,
             .SILBoxType,
             .SILBoxTypeWithLayout,
             .Structure,
             .OtherNominalType,
             .TupleElementName,
             .TypeAlias,
             .TypeList,
             .LabelList,
             .TypeSymbolicReference,
             .SugaredOptional,
             .SugaredArray,
             .SugaredDictionary,
             .SugaredParen:
            return true
        case .Type:
            return firstChild.isSimpleType
        case .ProtocolList:
            return _children[0].numberOfChildren <= 1
        case .ProtocolListWithAnyObject:
            return _children[0]._children[0].numberOfChildren == 0
        case .ProtocolListWithClass,
             .AccessorFunctionReference,
             .Allocator,
             .ArgumentTuple,
             .AssociatedConformanceDescriptor,
             .AssociatedTypeDescriptor,
             .AssociatedTypeMetadataAccessor,
             .AssociatedTypeWitnessTableAccessor,
             .AutoClosureType,
             .BaseConformanceDescriptor,
             .BaseWitnessTableAccessor,
             .ClangType,
             .ClassMetadataBaseOffset,
             .CFunctionPointer,
             .Constructor,
             .CoroutineContinuationPrototype,
             .CurryThunk,
             .DispatchThunk,
             .Deallocator,
             .DeclContext,
             .DefaultArgumentInitializer,
             .DefaultAssociatedTypeMetadataAccessor,
             .DefaultAssociatedConformanceAccessor,
             .DependentAssociatedTypeRef,
             .DependentGenericSignature,
             .DependentGenericParamCount,
             .DependentGenericConformanceRequirement,
             .DependentGenericLayoutRequirement,
             .DependentGenericSameTypeRequirement,
             .DependentPseudogenericSignature,
             .Destructor,
             .DidSet,
             .DirectMethodReferenceAttribute,
             .Directness,
             .DynamicAttribute,
             .EscapingAutoClosureType,
             .EscapingObjCBlock,
             .NoEscapeFunctionType,
             .ExplicitClosure,
             .Extension,
             .EnumCase,
             .FieldOffset,
             .FullObjCResilientClassStub,
             .FullTypeMetadata,
             .Function,
             .FunctionSignatureSpecialization,
             .FunctionSignatureSpecializationParam,
             .FunctionSignatureSpecializationReturn,
             .FunctionSignatureSpecializationParamKind,
             .FunctionSignatureSpecializationParamPayload,
             .FunctionType,
             .GenericProtocolWitnessTable,
             .GenericProtocolWitnessTableInstantiationFunction,
             .GenericPartialSpecialization,
             .GenericPartialSpecializationNotReAbstracted,
             .GenericSpecialization,
             .GenericSpecializationNotReAbstracted,
             .GenericSpecializationInResilienceDomain,
             .GenericSpecializationParam,
             .GenericSpecializationPrespecialized,
             .InlinedGenericFunction,
             .GenericTypeMetadataPattern,
             .Getter,
             .Global,
             .GlobalGetter,
             .Identifier,
             .Index,
             .IVarInitializer,
             .IVarDestroyer,
             .ImplDifferentiabilityKind,
             .ImplEscaping,
             .ImplConvention,
             .ImplParameterResultDifferentiability,
             .ImplFunctionAttribute,
             .ImplFunctionConvention,
             .ImplFunctionConventionName,
             .ImplFunctionType,
             .ImplInvocationSubstitutions,
             .ImplPatternSubstitutions,
             .ImplicitClosure,
             .ImplParameter,
             .ImplResult,
             .ImplYield,
             .ImplErrorResult,
             .InOut,
             .InfixOperator,
             .Initializer,
             .Isolated,
             .PropertyWrapperBackingInitializer,
             .PropertyWrapperInitFromProjectedValue,
             .KeyPathGetterThunkHelper,
             .KeyPathSetterThunkHelper,
             .KeyPathEqualsThunkHelper,
             .KeyPathHashThunkHelper,
             .LazyProtocolWitnessTableAccessor,
             .LazyProtocolWitnessTableCacheVariable,
             .LocalDeclName,
             .MaterializeForSet,
             .MergedFunction,
             .Metaclass,
             .MethodDescriptor,
             .MethodLookupFunction,
             .ModifyAccessor,
             .NativeOwningAddressor,
             .NativeOwningMutableAddressor,
             .NativePinningAddressor,
             .NativePinningMutableAddressor,
             .NominalTypeDescriptor,
             .NonObjCAttribute,
             .Number,
             .ObjCAsyncCompletionHandlerImpl,
             .ObjCAttribute,
             .ObjCBlock,
             .ObjCMetadataUpdateFunction,
             .ObjCResilientClassStub,
             .OpaqueTypeDescriptor,
             .OpaqueTypeDescriptorAccessor,
             .OpaqueTypeDescriptorAccessorImpl,
             .OpaqueTypeDescriptorAccessorKey,
             .OpaqueTypeDescriptorAccessorVar,
             .Owned,
             .OwningAddressor,
             .OwningMutableAddressor,
             .PartialApplyForwarder,
             .PartialApplyObjCForwarder,
             .PostfixOperator,
             .PredefinedObjCAsyncCompletionHandlerImpl,
             .PrefixOperator,
             .PrivateDeclName,
             .PropertyDescriptor,
             .ProtocolConformance,
             .ProtocolConformanceDescriptor,
             .MetadataInstantiationCache,
             .ProtocolDescriptor,
             .ProtocolRequirementsBaseDescriptor,
             .ProtocolSelfConformanceDescriptor,
             .ProtocolSelfConformanceWitness,
             .ProtocolSelfConformanceWitnessTable,
             .ProtocolWitness,
             .ProtocolWitnessTable,
             .ProtocolWitnessTableAccessor,
             .ProtocolWitnessTablePattern,
             .ReabstractionThunk,
             .ReabstractionThunkHelper,
             .ReabstractionThunkHelperWithSelf,
             .ReabstractionThunkHelperWithGlobalActor,
             .ReadAccessor,
             .RelatedEntityDeclName,
             .RetroactiveConformance,
             .Setter,
             .Shared,
             .SILBoxLayout,
             .SILBoxMutableField,
             .SILBoxImmutableField,
             .IsSerialized,
             .SpecializationPassID,
             .Static,
             .Subscript,
             .Suffix,
             .ThinFunctionType,
             .TupleElement,
             .TypeMangling,
             .TypeMetadata,
             .TypeMetadataAccessFunction,
             .TypeMetadataCompletionFunction,
             .TypeMetadataInstantiationCache,
             .TypeMetadataInstantiationFunction,
             .TypeMetadataSingletonInitializationCache,
             .TypeMetadataDemanglingCache,
             .TypeMetadataLazyCache,
             .UncurriedFunctionType,
             .Weak,
             .Unowned,
             .Unmanaged,
             .UnknownIndex,
             .UnsafeAddressor,
             .UnsafeMutableAddressor,
             .ValueWitness,
             .ValueWitnessTable,
             .Variable,
             .VTableAttribute,
             .VTableThunk,
             .WillSet,
             .ReflectionMetadataBuiltinDescriptor,
             .ReflectionMetadataFieldDescriptor,
             .ReflectionMetadataAssocTypeDescriptor,
             .ReflectionMetadataSuperclassDescriptor,
             .ResilientProtocolWitnessTable,
             .GenericTypeParamDecl,
             .ConcurrentFunctionType,
             .GlobalActorFunctionType,
             .DifferentiableFunctionType,
             .AsyncAnnotation,
             .ThrowsAnnotation,
             .EmptyList,
             .FirstElementMarker,
             .VariadicMarker,
             .OutlinedBridgedMethod,
             .OutlinedCopy,
             .OutlinedConsume,
             .OutlinedRetain,
             .OutlinedRelease,
             .OutlinedInitializeWithTake,
             .OutlinedInitializeWithCopy,
             .OutlinedAssignWithTake,
             .OutlinedAssignWithCopy,
             .OutlinedDestroy,
             .OutlinedVariable,
             .AssocTypePath,
             .ModuleDescriptor,
             .AnonymousDescriptor,
             .AssociatedTypeGenericParamRef,
             .ExtensionDescriptor,
             .AnonymousContext,
             .AnyProtocolConformanceList,
             .ConcreteProtocolConformance,
             .DependentAssociatedConformance,
             .DependentProtocolConformanceAssociated,
             .DependentProtocolConformanceInherited,
             .DependentProtocolConformanceRoot,
             .ProtocolConformanceRefInTypeModule,
             .ProtocolConformanceRefInProtocolModule,
             .ProtocolConformanceRefInOtherModule,
             .DynamicallyReplaceableFunctionKey,
             .DynamicallyReplaceableFunctionImpl,
             .DynamicallyReplaceableFunctionVar,
             .OpaqueType,
             .OpaqueTypeDescriptorSymbolicReference,
             .OpaqueReturnType,
             .OpaqueReturnTypeOf,
             .CanonicalSpecializedGenericMetaclass,
             .CanonicalSpecializedGenericTypeMetadataAccessFunction,
             .NoncanonicalSpecializedGenericTypeMetadata,
             .NoncanonicalSpecializedGenericTypeMetadataCache,
             .GlobalVariableOnceDeclList,
             .GlobalVariableOnceFunction,
             .GlobalVariableOnceToken,
             .CanonicalPrespecializedGenericTypeCachingOnceToken,
             .AsyncFunctionPointer,
             .AutoDiffFunction,
             .AutoDiffDerivativeVTableThunk,
             .AutoDiffSelfReorderingReabstractionThunk,
             .AutoDiffSubsetParametersThunk,
             .AutoDiffFunctionKind,
             .DifferentiabilityWitness,
             .NoDerivative,
             .IndexSubset,
             .AsyncAwaitResumePartialFunction,
             .AsyncSuspendResumePartialFunction:
            return false
        }
    }
    
    var isExistentialType: Bool {
        [Kind.ExistentialMetatype, .ProtocolList, .ProtocolListWithClass, .ProtocolListWithAnyObject].contains(kind)
    }
    
    public var isClassType: Bool { kind == .Class }
    
    var isAlias: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isAlias
        case .TypeAlias:
            return true
        default:
            return false
        }
    }
    
    var isClass: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isClass
        case .Class, .BoundGenericClass:
            return true
        default:
            return false
        }
    }
    
    var isEnum: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isEnum
        case .Enum, .BoundGenericEnum:
            return true
        default:
            return false
        }
    }
    
    var isProtocol: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isProtocol
        case .Protocol, .ProtocolSymbolicReference:
            return true
        default:
            return false
        }
    }
    
    var isStruct: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isStruct
        case .Structure, .BoundGenericStructure:
            return true
        default:
            return false
        }
    }
    
    var isConsumesGenericArgs: Bool {
        switch kind {
        case .Variable,
             .Subscript,
             .ImplicitClosure,
             .ExplicitClosure,
             .DefaultArgumentInitializer,
             .Initializer,
             .PropertyWrapperBackingInitializer,
             .PropertyWrapperInitFromProjectedValue:
            return false
        default:
            return true
        }
    }
    
    var isSpecialized: Bool {
        switch kind {
        case .BoundGenericStructure,.BoundGenericEnum,.BoundGenericClass,.BoundGenericOtherNominalType,.BoundGenericTypeAlias,.BoundGenericProtocol,.BoundGenericFunction:
            return true
        case .Structure, .Enum, .Class, .TypeAlias, .OtherNominalType, .Protocol, .Function, .Allocator, .Constructor, .Destructor, .Variable, .Subscript, .ExplicitClosure, .ImplicitClosure, .Initializer, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue, .DefaultArgumentInitializer, .Getter, .Setter, .WillSet, .DidSet, .ReadAccessor, .ModifyAccessor, .UnsafeAddressor, .UnsafeMutableAddressor:
            return firstChild.isSpecialized
        case .Extension:
            return children(1).isSpecialized
        default:
            return false
        }
    }
    
    func unspecialized() -> Node? {
        var NumToCopy = 2
        switch kind {
        case .Function, .Getter, .Setter, .WillSet, .DidSet, .ReadAccessor, .ModifyAccessor, .UnsafeAddressor, .UnsafeMutableAddressor, .Allocator, .Constructor, .Destructor, .Variable, .Subscript, .ExplicitClosure, .ImplicitClosure, .Initializer, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue, .DefaultArgumentInitializer:
            NumToCopy = numberOfChildren
            fallthrough
        case .Structure, .Enum, .Class, .TypeAlias, .OtherNominalType:
            let result = Node(kind)
            var parentOrModule: Node? = firstChild
            if parentOrModule?.isSpecialized == true {
                parentOrModule = parentOrModule?.unspecialized()
            }
            result.addChild(parentOrModule)
            if NumToCopy > 0 {
                for index in 0..<NumToCopy {
                    result.addChild(getChild(index))
                }
            }
            return result
            
        case .BoundGenericStructure, .BoundGenericEnum, .BoundGenericClass, .BoundGenericProtocol, .BoundGenericOtherNominalType, .BoundGenericTypeAlias:
            let unboundType = getChild(0)
            assert(unboundType.getKind() == .Type)
            let nominalType = unboundType.getChild(0)
            if nominalType.isSpecialized {
                return nominalType.unspecialized()
            }
            return nominalType
        case .BoundGenericFunction:
            let unboundFunction = getChild(0)
            assert(unboundFunction.getKind() == .Function || unboundFunction.getKind() == .Constructor)
            if unboundFunction.isSpecialized {
                return unboundFunction.unspecialized()
            }
            return unboundFunction
        case .Extension:
            let parent = getChild(1)
            if !parent.isSpecialized {
                return self
            }
            let result = Node(.Extension)
            result.addChild(firstChild)
            result.addChild(parent.unspecialized())
            if numberOfChildren == 3 {
                // Add the generic signature of the extension.
                result.addChild(getChild(2))
            }
            return result
        default:
            assertionFailure("bad nominal type kind")
        }
        return nil
    }
}

extension Node {
    public enum Payload: Equatable {
        case none
        case text(String)
        case index(UInt64)
        case valueWitnessKind(ValueWitnessKind)
        case mangledDifferentiabilityKind(MangledDifferentiabilityKind)
        case functionSigSpecializationParamKind(FunctionSigSpecializationParamKind)
        case directness(Directness)
        case onechild
        case twochildren
        case manychildren
        
        var isChildren: Bool {
            switch self {
            case .none, .onechild, .twochildren, .manychildren:
                return true
            default:
                return false
            }
        }
        
        var isText: Bool {
            switch self {
            case .text: return true
            default: return false
            }
        }
    }
    
    public enum Kind: String, Equatable {//}, CustomStringConvertible, CustomDebugStringConvertible {
        case Allocator
        case AnonymousContext
        case AnyProtocolConformanceList
        case ArgumentTuple
        case AssociatedType
        case AssociatedTypeRef
        case AssociatedTypeMetadataAccessor
        case DefaultAssociatedTypeMetadataAccessor
        case AssociatedTypeWitnessTableAccessor
        case BaseWitnessTableAccessor
        case AutoClosureType
        case BoundGenericClass
        case BoundGenericEnum
        case BoundGenericStructure
        case BoundGenericProtocol
        case BoundGenericOtherNominalType
        case BoundGenericTypeAlias
        case BoundGenericFunction
        case BuiltinTypeName
        case CFunctionPointer
        case ClangType
        case Class
        case ClassMetadataBaseOffset
        case ConcreteProtocolConformance
        case Constructor
        case CoroutineContinuationPrototype
        case Deallocator
        case DeclContext
        case DefaultArgumentInitializer
        case DependentAssociatedConformance
        case DependentAssociatedTypeRef
        case DependentGenericConformanceRequirement
        case DependentGenericParamCount
        case DependentGenericParamType
        case DependentGenericSameTypeRequirement
        case DependentGenericLayoutRequirement
        case DependentGenericSignature
        case DependentGenericType
        case DependentMemberType
        case DependentPseudogenericSignature
        case DependentProtocolConformanceRoot
        case DependentProtocolConformanceInherited
        case DependentProtocolConformanceAssociated
        case Destructor
        case DidSet
        case Directness
        case DynamicAttribute
        case DirectMethodReferenceAttribute
        case DynamicSelf
        case DynamicallyReplaceableFunctionImpl
        case DynamicallyReplaceableFunctionKey
        case DynamicallyReplaceableFunctionVar
        case Enum
        case EnumCase
        case ErrorType
        case EscapingAutoClosureType
        case NoEscapeFunctionType
        case ConcurrentFunctionType
        case GlobalActorFunctionType
        case DifferentiableFunctionType
        case ExistentialMetatype
        case ExplicitClosure
        case Extension
        case FieldOffset
        case FullTypeMetadata
        case Function
        case FunctionSignatureSpecialization
        case FunctionSignatureSpecializationParam
        case FunctionSignatureSpecializationReturn
        case FunctionSignatureSpecializationParamKind
        case FunctionSignatureSpecializationParamPayload
        case FunctionType
        case GenericPartialSpecialization
        case GenericPartialSpecializationNotReAbstracted
        case GenericProtocolWitnessTable
        case GenericProtocolWitnessTableInstantiationFunction
        case ResilientProtocolWitnessTable
        case GenericSpecialization
        case GenericSpecializationNotReAbstracted
        case GenericSpecializationInResilienceDomain
        case GenericSpecializationParam
        case GenericSpecializationPrespecialized
        case InlinedGenericFunction
        case GenericTypeMetadataPattern
        case Getter
        case Global
        case GlobalGetter
        case Identifier
        case Index
        case IVarInitializer
        case IVarDestroyer
        case ImplEscaping
        case ImplConvention
        case ImplDifferentiabilityKind
        case ImplParameterResultDifferentiability
        case ImplFunctionAttribute
        case ImplFunctionConvention
        case ImplFunctionConventionName
        case ImplFunctionType
        case ImplInvocationSubstitutions
        case ImplicitClosure
        case ImplParameter
        case ImplPatternSubstitutions
        case ImplResult
        case ImplYield
        case ImplErrorResult
        case InOut
        case InfixOperator
        case Initializer
        case Isolated
        case KeyPathGetterThunkHelper
        case KeyPathSetterThunkHelper
        case KeyPathEqualsThunkHelper
        case KeyPathHashThunkHelper
        case LazyProtocolWitnessTableAccessor
        case LazyProtocolWitnessTableCacheVariable
        case LocalDeclName
        case MaterializeForSet
        case MergedFunction
        case Metatype
        case MetatypeRepresentation
        case Metaclass
        case MethodLookupFunction
        case ObjCMetadataUpdateFunction
        case ObjCResilientClassStub
        case FullObjCResilientClassStub
        case ModifyAccessor
        case Module
        case NativeOwningAddressor
        case NativeOwningMutableAddressor
        case NativePinningAddressor
        case NativePinningMutableAddressor
        case NominalTypeDescriptor
        case NonObjCAttribute
        case Number
        case ObjCAsyncCompletionHandlerImpl
        case PredefinedObjCAsyncCompletionHandlerImpl
        case ObjCAttribute
        case ObjCBlock
        case EscapingObjCBlock
        case OtherNominalType
        case OwningAddressor
        case OwningMutableAddressor
        case PartialApplyForwarder
        case PartialApplyObjCForwarder
        case PostfixOperator
        case PrefixOperator
        case PrivateDeclName
        case PropertyDescriptor
        case PropertyWrapperBackingInitializer
        case PropertyWrapperInitFromProjectedValue
        case `Protocol`
        case ProtocolSymbolicReference
        case ProtocolConformance
        case ProtocolConformanceRefInTypeModule
        case ProtocolConformanceRefInProtocolModule
        case ProtocolConformanceRefInOtherModule
        case ProtocolDescriptor
        case ProtocolConformanceDescriptor
        case ProtocolList
        case ProtocolListWithClass
        case ProtocolListWithAnyObject
        case ProtocolSelfConformanceDescriptor
        case ProtocolSelfConformanceWitness
        case ProtocolSelfConformanceWitnessTable
        case ProtocolWitness
        case ProtocolWitnessTable
        case ProtocolWitnessTableAccessor
        case ProtocolWitnessTablePattern
        case ReabstractionThunk
        case ReabstractionThunkHelper
        case ReabstractionThunkHelperWithSelf
        case ReabstractionThunkHelperWithGlobalActor
        case ReadAccessor
        case RelatedEntityDeclName
        case RetroactiveConformance
        case ReturnType
        case Shared
        case Owned
        case SILBoxType
        case SILBoxTypeWithLayout
        case SILBoxLayout
        case SILBoxMutableField
        case SILBoxImmutableField
        case Setter
        case SpecializationPassID
        case IsSerialized
        case Static
        case Structure
        case Subscript
        case Suffix
        case ThinFunctionType
        case Tuple
        case TupleElement
        case TupleElementName
        case `Type`
        case TypeSymbolicReference
        case TypeAlias
        case TypeList
        case TypeMangling
        case TypeMetadata
        case TypeMetadataAccessFunction
        case TypeMetadataCompletionFunction
        case TypeMetadataInstantiationCache
        case TypeMetadataInstantiationFunction
        case TypeMetadataSingletonInitializationCache
        case TypeMetadataDemanglingCache
        case TypeMetadataLazyCache
        case UncurriedFunctionType
        case UnknownIndex
        // REF_STORAGE start
        case Weak
        case Unowned
        case Unmanaged
        // REF_STORAGE end
        case UnsafeAddressor
        case UnsafeMutableAddressor
        case ValueWitness
        case ValueWitnessTable
        case Variable
        case VTableThunk
        case VTableAttribute // note: old mangling only
        case WillSet
        case ReflectionMetadataBuiltinDescriptor
        case ReflectionMetadataFieldDescriptor
        case ReflectionMetadataAssocTypeDescriptor
        case ReflectionMetadataSuperclassDescriptor
        case GenericTypeParamDecl
        case CurryThunk
        case DispatchThunk
        case MethodDescriptor
        case ProtocolRequirementsBaseDescriptor
        case AssociatedConformanceDescriptor
        case DefaultAssociatedConformanceAccessor
        case BaseConformanceDescriptor
        case AssociatedTypeDescriptor
        case AsyncAnnotation
        case ThrowsAnnotation
        case EmptyList
        case FirstElementMarker
        case VariadicMarker
        case OutlinedBridgedMethod
        case OutlinedCopy
        case OutlinedConsume
        case OutlinedRetain
        case OutlinedRelease
        case OutlinedInitializeWithTake
        case OutlinedInitializeWithCopy
        case OutlinedAssignWithTake
        case OutlinedAssignWithCopy
        case OutlinedDestroy
        case OutlinedVariable
        case AssocTypePath
        case LabelList
        case ModuleDescriptor
        case ExtensionDescriptor
        case AnonymousDescriptor
        case AssociatedTypeGenericParamRef
        case SugaredOptional
        case SugaredArray
        case SugaredDictionary
        case SugaredParen
        
        // Added in Swift 5.1
        case AccessorFunctionReference
        case OpaqueType
        case OpaqueTypeDescriptorSymbolicReference
        case OpaqueTypeDescriptor
        case OpaqueTypeDescriptorAccessor
        case OpaqueTypeDescriptorAccessorImpl
        case OpaqueTypeDescriptorAccessorKey
        case OpaqueTypeDescriptorAccessorVar
        case OpaqueReturnType
        case OpaqueReturnTypeOf
        
        // Added in Swift 5.4
        case CanonicalSpecializedGenericMetaclass
        case CanonicalSpecializedGenericTypeMetadataAccessFunction
        case MetadataInstantiationCache
        case NoncanonicalSpecializedGenericTypeMetadata
        case NoncanonicalSpecializedGenericTypeMetadataCache
        case GlobalVariableOnceFunction
        case GlobalVariableOnceToken
        case GlobalVariableOnceDeclList
        case CanonicalPrespecializedGenericTypeCachingOnceToken
        
        // Added in Swift 5.5
        case AsyncFunctionPointer
        case AutoDiffFunction
        case AutoDiffFunctionKind
        case AutoDiffSelfReorderingReabstractionThunk
        case AutoDiffSubsetParametersThunk
        case AutoDiffDerivativeVTableThunk
        case DifferentiabilityWitness
        case NoDerivative
        case IndexSubset
        case AsyncAwaitResumePartialFunction
        case AsyncSuspendResumePartialFunction
        
        //        public var name: String {
        //            if let first = rawValue.first {
        //                return first.uppercased() + rawValue.dropFirst(1)
        //            }
        //            return rawValue
        //        }
        
        public func `in`(_ kinds: Self...) -> Bool {
            kinds.contains(self)
        }
        
        //        public var description: String { name }
        //        public var debugDescription: String { "Node." + rawValue }
    }
    
    public enum IsVariadic {
        case yes, no
    }
    
    public enum Directness {
        case direct, indirect, unknown
        
        var text: String {
            switch self {
            case .direct:
                return "direct"
            case .indirect:
                return "indirect"
            case .unknown:
                return ""
            }
        }
    }
    
    public enum ValueWitnessKind {
        case AllocateBuffer
        case AssignWithCopy
        case AssignWithTake
        case DeallocateBuffer
        case Destroy
        case DestroyBuffer
        case DestroyArray
        case InitializeBufferWithCopyOfBuffer
        case InitializeBufferWithCopy
        case InitializeWithCopy
        case InitializeBufferWithTake
        case InitializeWithTake
        case ProjectBuffer
        case InitializeBufferWithTakeOfBuffer
        case InitializeArrayWithCopy
        case InitializeArrayWithTakeFrontToBack
        case InitializeArrayWithTakeBackToFront
        case StoreExtraInhabitant
        case GetExtraInhabitantIndex
        case GetEnumTag
        case DestructiveProjectEnumData
        case DestructiveInjectEnumTag
        case GetEnumTagSinglePayload
        case StoreEnumTagSinglePayload
        
        init?(code: String) {
            switch code {
            case "al": self = .AllocateBuffer
            case "ca": self = .AssignWithCopy
            case "ta": self = .AssignWithTake
            case "de": self = .DeallocateBuffer
            case "xx": self = .Destroy
            case "XX": self = .DestroyBuffer
            case "Xx": self = .DestroyArray
            case "CP": self = .InitializeBufferWithCopyOfBuffer
            case "Cp": self = .InitializeBufferWithCopy
            case "cp": self = .InitializeWithCopy
            case "Tk": self = .InitializeBufferWithTake
            case "tk": self = .InitializeWithTake
            case "pr": self = .ProjectBuffer
            case "TK": self = .InitializeBufferWithTakeOfBuffer
            case "Cc": self = .InitializeArrayWithCopy
            case "Tt": self = .InitializeArrayWithTakeFrontToBack
            case "tT": self = .InitializeArrayWithTakeBackToFront
            case "xs": self = .StoreExtraInhabitant
            case "xg": self = .GetExtraInhabitantIndex
            case "ug": self = .GetEnumTag
            case "up": self = .DestructiveProjectEnumData
            case "ui": self = .DestructiveInjectEnumTag
            case "et": self = .GetEnumTagSinglePayload
            case "st": self = .StoreEnumTagSinglePayload
            default:
                return nil
            }
        }
        
        var name: String {
            switch self {
            case .AllocateBuffer:
                return "AllocateBuffer".lowercasedOnlyFirst()
            case .AssignWithCopy:
                return "AssignWithCopy".lowercasedOnlyFirst()
            case .AssignWithTake:
                return "AssignWithTake".lowercasedOnlyFirst()
            case .DeallocateBuffer:
                return "DeallocateBuffer".lowercasedOnlyFirst()
            case .Destroy:
                return "Destroy".lowercasedOnlyFirst()
            case .DestroyBuffer:
                return "DestroyBuffer".lowercasedOnlyFirst()
            case .DestroyArray:
                return "DestroyArray".lowercasedOnlyFirst()
            case .InitializeBufferWithCopyOfBuffer:
                return "InitializeBufferWithCopyOfBuffer".lowercasedOnlyFirst()
            case .InitializeBufferWithCopy:
                return "InitializeBufferWithCopy".lowercasedOnlyFirst()
            case .InitializeWithCopy:
                return "InitializeWithCopy".lowercasedOnlyFirst()
            case .InitializeBufferWithTake:
                return "InitializeBufferWithTake".lowercasedOnlyFirst()
            case .InitializeWithTake:
                return "InitializeWithTake".lowercasedOnlyFirst()
            case .ProjectBuffer:
                return "ProjectBuffer".lowercasedOnlyFirst()
            case .InitializeBufferWithTakeOfBuffer:
                return "InitializeBufferWithTakeOfBuffer".lowercasedOnlyFirst()
            case .InitializeArrayWithCopy:
                return "InitializeArrayWithCopy".lowercasedOnlyFirst()
            case .InitializeArrayWithTakeFrontToBack:
                return "InitializeArrayWithTakeFrontToBack".lowercasedOnlyFirst()
            case .InitializeArrayWithTakeBackToFront:
                return "InitializeArrayWithTakeBackToFront".lowercasedOnlyFirst()
            case .StoreExtraInhabitant:
                return "StoreExtraInhabitant".lowercasedOnlyFirst()
            case .GetExtraInhabitantIndex:
                return "GetExtraInhabitantIndex".lowercasedOnlyFirst()
            case .GetEnumTag:
                return "GetEnumTag".lowercasedOnlyFirst()
            case .DestructiveProjectEnumData:
                return "DestructiveProjectEnumData".lowercasedOnlyFirst()
            case .DestructiveInjectEnumTag:
                return "DestructiveInjectEnumTag".lowercasedOnlyFirst()
            case .GetEnumTagSinglePayload:
                return "GetEnumTagSinglePayload".lowercasedOnlyFirst()
            case .StoreEnumTagSinglePayload:
                return "StoreEnumTagSinglePayload".lowercasedOnlyFirst()
            }
        }
    }
}

extension Node: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let kind = self.kind
        let payload = self.payload
        let children = self._children
        let numberOfParent = self.numberOfParent
        let prefix = [String](repeating: "  ", count: numberOfParent).joined()
        if numberOfChildren > 0 {
            return "\(numberOfParent > 0 ? "\n" : "")\(prefix)Kind: \(kind) \(children.map(\.debugDescription).joined(separator: ", "))"
        } else {
            return "\(numberOfParent > 0 ? "\n" : "")\(prefix)Kind: \(kind), Payload: \(payload)"
        }
    }
    
}

extension Node.Kind {
    
    private static func array(_ kind: Node.Kind...) -> [Node.Kind] {
        kind
    }
    
    private static let declNames: [Node.Kind] = array(.Identifier, .LocalDeclName, .PrivateDeclName, .RelatedEntityDeclName, .PrefixOperator, .PostfixOperator, .InfixOperator, .TypeSymbolicReference, .ProtocolSymbolicReference)
    private static let anyGenerics: [Node.Kind] = array(.Structure, .Class, .Enum, .Protocol, .ProtocolSymbolicReference, .OtherNominalType, .TypeAlias, .TypeSymbolicReference)
    private static let requirements = array(.DependentGenericSameTypeRequirement, .DependentGenericLayoutRequirement, .DependentGenericConformanceRequirement)
    private static let contexts = array(.Allocator, .AnonymousContext, .Class, .Constructor, .Deallocator, .DefaultArgumentInitializer, .Destructor, .DidSet, .Enum, .ExplicitClosure, .Extension, .Function, .Getter, .GlobalGetter, .IVarInitializer, .IVarDestroyer, .ImplicitClosure, .Initializer, .MaterializeForSet, .ModifyAccessor, .Module, .NativeOwningAddressor, .NativeOwningMutableAddressor, .NativePinningAddressor, .NativePinningMutableAddressor, .OtherNominalType, .OwningAddressor, .OwningMutableAddressor, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue, .Protocol, .ProtocolSymbolicReference, .ReadAccessor, .Setter, .Static, .Structure, .Subscript, .TypeSymbolicReference, .TypeAlias, .UnsafeAddressor, .UnsafeMutableAddressor, .Variable, .WillSet, .OpaqueReturnTypeOf, .AutoDiffFunction)
    private static let functionAttrs = array(.FunctionSignatureSpecialization, .GenericSpecialization, .GenericSpecializationPrespecialized, .InlinedGenericFunction, .GenericSpecializationNotReAbstracted, .GenericPartialSpecialization, .GenericPartialSpecializationNotReAbstracted, .GenericSpecializationInResilienceDomain, .ObjCAttribute, .NonObjCAttribute, .DynamicAttribute, .DirectMethodReferenceAttribute, .VTableAttribute, .PartialApplyForwarder, .PartialApplyObjCForwarder, .OutlinedVariable, .OutlinedBridgedMethod, .MergedFunction, .DynamicallyReplaceableFunctionImpl, .DynamicallyReplaceableFunctionKey, .DynamicallyReplaceableFunctionVar, .AsyncFunctionPointer, .AsyncAwaitResumePartialFunction, .AsyncSuspendResumePartialFunction)
    
    var isDeclName: Bool {
        Self.declNames.contains(self)
    }
    
    var isAnyGeneric: Bool {
        Self.anyGenerics.contains(self)
    }
    
    var isEntity: Bool {
        if self == .Type {
            return true
        } else {
            return isContext
        }
    }
    
    var isRequirement: Bool {
        Self.requirements.contains(self)
    }
    
    
    var isContext: Bool {
        Self.contexts.contains(self)
    }
    
    var isFunctionAttr: Bool {
        Self.functionAttrs.contains(self)
    }
}

extension Optional where Wrapped == Node {
    var isAlias: Bool {
        if let node = self {
            return node.isAlias
        } else {
            return false
        }
    }
    var isClass: Bool {
        if let node = self {
            return node.isClass
        } else {
            return false
        }
    }
    var isEnum: Bool {
        if let node = self {
            return node.isEnum
        } else {
            return false
        }
    }
    var isProtocol: Bool {
        if let node = self {
            return node.isProtocol
        } else {
            return false
        }
    }
    var isStruct: Bool {
        if let node = self {
            return node.isStruct
        } else {
            return false
        }
    }
}

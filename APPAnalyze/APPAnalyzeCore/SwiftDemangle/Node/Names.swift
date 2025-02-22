//
//  Names.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/30.
//

import Foundation

extension String {
    /// The name of the standard library, which is a reserved module name.
    static let STDLIB_NAME = "Swift"
    /// The name of the Onone support library, which is a reserved module name.
    static let SWIFT_ONONE_SUPPORT = "SwiftOnoneSupport"
    /// The name of the Concurrency module, which supports that extension.
    static let SWIFT_CONCURRENCY_NAME = "_Concurrency"
    /// The name of the SwiftShims module, which contains private stdlib decls.
    static let SWIFT_SHIMS_NAME = "SwiftShims"
    /// The name of the Builtin module, which contains Builtin functions.
    static let BUILTIN_NAME = "Builtin"
    /// The name of the clang imported header module.
    static let CLANG_HEADER_MODULE_NAME = "__ObjC"
    /// The prefix of module names used by LLDB to capture Swift expressions
    static let LLDB_EXPRESSIONS_MODULE_NAME_PREFIX =
        "__lldb_expr_"
    
    /// The name of the fake module used to hold imported Objective-C things.
    static let MANGLING_MODULE_OBJC = "__C"
    /// The name of the fake module used to hold synthesized ClangImporter things.
    static let MANGLING_MODULE_CLANG_IMPORTER =
        "__C_Synthesized"
    
    /// The name prefix for C++ template instantiation imported as a Swift struct.
    static let CXX_TEMPLATE_INST_PREFIX =
        "__CxxTemplateInst"
    
    static let SEMANTICS_PROGRAMTERMINATION_POINT =
        "programtermination_point"
    
    /// The name of the Builtin type prefix
    static let BUILTIN_TYPE_NAME_PREFIX = "Builtin."
    
    static let BUILTIN_TYPE_NAME_INT = "Builtin.Int"
    /// The name of the Builtin type for Int8
    static let BUILTIN_TYPE_NAME_INT8 = "Builtin.Int8"
    /// The name of the Builtin type for Int16
    static let BUILTIN_TYPE_NAME_INT16 = "Builtin.Int16"
    /// The name of the Builtin type for Int32
    static let BUILTIN_TYPE_NAME_INT32 = "Builtin.Int32"
    /// The name of the Builtin type for Int64
    static let BUILTIN_TYPE_NAME_INT64 = "Builtin.Int64"
    /// The name of the Builtin type for Int128
    static let BUILTIN_TYPE_NAME_INT128 = "Builtin.Int128"
    /// The name of the Builtin type for Int256
    static let BUILTIN_TYPE_NAME_INT256 = "Builtin.Int256"
    /// The name of the Builtin type for Int512
    static let BUILTIN_TYPE_NAME_INT512 = "Builtin.Int512"
    /// The name of the Builtin type for IntLiteral
    static let BUILTIN_TYPE_NAME_INTLITERAL = "Builtin.IntLiteral"
    /// The name of the Builtin type for IEEE Floating point types.
    static let BUILTIN_TYPE_NAME_FLOAT = "Builtin.FPIEEE"
    // The name of the builtin type for power pc specific floating point types.
    static let BUILTIN_TYPE_NAME_FLOAT_PPC = "Builtin.FPPPC"
    /// The name of the Builtin type for NativeObject
    static let BUILTIN_TYPE_NAME_NATIVEOBJECT = "Builtin.NativeObject"
    /// The name of the Builtin type for BridgeObject
    static let BUILTIN_TYPE_NAME_BRIDGEOBJECT = "Builtin.BridgeObject"
    /// The name of the Builtin type for RawPointer
    static let BUILTIN_TYPE_NAME_RAWPOINTER = "Builtin.RawPointer"
    /// The name of the Builtin type for RawUnsafeContinuation
    static let BUILTIN_TYPE_NAME_RAWUNSAFECONTINUATION = "Builtin.RawUnsafeContinuation"
    /// The name of the Builtin type for UnsafeValueBuffer
    static let BUILTIN_TYPE_NAME_UNSAFEVALUEBUFFER = "Builtin.UnsafeValueBuffer"
    /// The name of the Builtin type for Job
    static let BUILTIN_TYPE_NAME_JOB = "Builtin.Job"
    /// The name of the Builtin type for ExecutorRef
    static let BUILTIN_TYPE_NAME_EXECUTOR = "Builtin.Executor"
    /// The name of the Builtin type for DefaultActorStorage
    static let BUILTIN_TYPE_NAME_DEFAULTACTORSTORAGE = "Builtin.DefaultActorStorage"
    /// The name of the Builtin type for UnknownObject
    ///
    /// This no longer exists as an AST-accessible type, but it's still used for
    /// fields shaped like AnyObject when ObjC interop is enabled.
    static let BUILTIN_TYPE_NAME_UNKNOWNOBJECT = "Builtin.UnknownObject"
    /// The name of the Builtin type for Vector
    static let BUILTIN_TYPE_NAME_VEC = "Builtin.Vec"
    /// The name of the Builtin type for SILToken
    static let BUILTIN_TYPE_NAME_SILTOKEN = "Builtin.SILToken"
    /// The name of the Builtin type for Word
    static let BUILTIN_TYPE_NAME_WORD = "Builtin.Word"
}

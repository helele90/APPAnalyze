//
//  Macho.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/27.
//

import Foundation

/// 指令集架构
public enum ArchType: String {
    case arm64
    case x86_64
}

/// ObjC  属性 Ivar
public struct ObjCIvarRef: Hashable {
    let `class`: String
    let name: String
    
    public init(`class`: String, name: String) {
        self.class = `class`
        self.name = name
    }
    
}

/// MachO 结构
public class MachO {
    public let name: String

    let classlist2: [ObjcClass]
    let protolist2: [ObjcProtocol]

    public let classlist: Set<String>
    public let catlist: [ObjcCategory]
    public let protolist: Set<String>
    public let classrefs: Set<String>
    public let superrefs: Set<String>
    public let selrefs: Set<String>
    
    /// `ObjC`使用的所有`Ivar`类型
    ///
    /// 所有属性的类型信息
    public let objcIvarTypeRefs: Set<String>
    
    public let usedStrings: Set<String>
    
    /// 使用的 `ObjC` Ivar 调用
    ///
    /// 使用_下划线调用的 `属性` 或 `Ivar`
    public let objcIvarRefs: Set<ObjCIvarRef>
    public let arch: ArchType

    public lazy var frameworkSize: LibrarySize = MachoTool.getFrameworkSize(path: path, arch: arch)

    /// 文件路径
    let path: String
    
    /// 定义的 `Swift` 符号
    public let symbols: [String: Symbol]
    
    /// 使用的 `Swift` 符号
    public let usedSymbols: Set<String>

    init(name: String, classlist: [String], catlist: [ObjcCategory], protolist: [String], classrefs: Set<String>, superrefs: Set<String>, selrefs: Set<String>, ivarTypeRefs: Set<String>, usedStrings: Set<String>, path: String, objcIvarRefs: Set<ObjCIvarRef>, arch: ArchType, classlist2: [ObjcClass], protolist2: [ObjcProtocol], symbols: [String: Symbol], usedSymbols: Set<String>) {
        self.name = name
        self.classlist = Set(classlist)
        self.catlist = catlist
        self.protolist = Set(protolist)
        self.classrefs = classrefs
        self.superrefs = superrefs
        self.selrefs = selrefs
        self.objcIvarTypeRefs = ivarTypeRefs
        self.usedStrings = usedStrings
        self.path = path
        self.objcIvarRefs = objcIvarRefs
        self.arch = arch
        self.classlist2 = classlist2
        self.protolist2 = protolist2
        self.symbols = symbols
        self.usedSymbols = usedSymbols
    }
    
    /// 所有实现 `+load` 方法的类
    public lazy var loadClasses: [String] = classlist.filter { APP.shared.classlist[$0]?.isLoadclass ?? false }

    /// 使用的所有协议
    public lazy var usedProtolist: Set<String> = {
        var usedProtolist: Set<String> = []
        classlist.forEach { className in
            if let objcClass = APP.shared.classlist[className] {
                for protocolName in objcClass.protocols {
                    usedProtolist.insert(protocolName)
                }
            }
        }
        return usedProtolist
    }()
}

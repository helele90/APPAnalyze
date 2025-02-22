//
//  ObjCModel.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/21.
//

import Foundation

/// ObjC方法
public struct ObjcMethod {
    public let name: String
    public let imp: String
}

/// ObjC属性
public struct ObjcProperty {
    public let name: String
    public let type: String
    public let attributes: String
}

/// ObjC协议
public struct ObjcProtocol: Hashable {
    public static func == (lhs: ObjcProtocol, rhs: ObjcProtocol) -> Bool {
        return lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public let name: String
    public let protocols: [String]
    public let instanceMethods: [String]
    public let classMethods: [String]
    public let optionalInstanceMethods: [String]
    public let optionalClassMethods: [String]
    public let instanceProperties: [ObjcProperty]
}

/// ObjC类
public class ObjcClass {
    public let name: String
    public internal(set) var superClassName: String
    public let instanceMethods: [String]
    public let classMethods: [String]
    public let ivars: [String]
    public let instanceProperties: [ObjcProperty]
    public let classProperties: [ObjcProperty]
    public let protocols: [String]
    public let isSwiftClass: Bool

    /// 实现 load 方法
    public var isLoadclass: Bool {
        return classMethods.contains("load")
    }

    /// 父类
    public var superclass: ObjcClass? {
        return APP.shared.classlist[superClassName]
    }

    /// 所有父类
    ///
    /// 包括继承链上的所有父类
    public private(set) var allSuperClass: [String] = []

    /// 实现的所有协议
    ///
    /// 包括继承链上所有父类实现的协议
    public private(set) var allProtocols: [String] = []

    init(name: String, superclassName: String, instanceMethods: [String], classMethods: [String], ivars: [String], instanceProperties: [ObjcProperty], classProperties: [ObjcProperty], protocols: [String], swiftClass: Bool) {
        self.name = name
        superClassName = superclassName
        self.instanceMethods = instanceMethods
        self.classMethods = classMethods
        self.ivars = ivars
        self.instanceProperties = instanceProperties
        self.classProperties = classProperties
        self.protocols = protocols
        isSwiftClass = swiftClass
    }

    func calculateAllSuperClassAndProtocol() {
        calculateAllSuperClass()
        calculateAllProtocol()
    }

    /// 计算类继承链上的所有父类
    func calculateAllSuperClass() {
        var classlist: [String] = []
        var superclass: ObjcClass? = self.superclass
        while superclass != nil {
            classlist.append(superclass!.name)
            if superclass?.name == "NSObject" {
                superclass = nil
            } else {
                superclass = superclass?.superclass
            }
        }

        allSuperClass = classlist
    }

    /// 计算类和所有父类实现的所有协议
    func calculateAllProtocol() {
        var child2: Set<String> = Set(self.protocols)
        var superclass: ObjcClass? = self.superclass
        while superclass != nil {
            if superclass?.name == "NSObject" {
                break
            }

            for protocolName in superclass!.protocols {
                child2.insert(protocolName)
            }

            superclass = superclass?.superclass
        }
        var child = Array(child2)
        //
        var addedProtocols: Set<String> = []
        //
        var protocols: Set<String> = []
        while !child.isEmpty {
            let count = child.count
            for protocolname in child {
                if let objcProtocol = APP.shared.protolist[protocolname] {
                    for protocolName in objcProtocol.protocols where !addedProtocols.contains(protocolName) {
                        child.append(protocolName)
                        addedProtocols.insert(protocolName)
                    }
                }
                //
                protocols.insert(protocolname)
            }
            //
            child.removeFirst(count)
        }
        //
        allProtocols = Array(protocols)
    }
}

extension ObjcClass: Hashable {
    public static func == (lhs: ObjcClass, rhs: ObjcClass) -> Bool {
        return lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// ObjC分类
public struct ObjcCategory {
    public let name: String
    public let cls: String
    public let instanceMethods: [String]
    public let classMethods: [String]
    public let protocols: [String]
    public let instanceProperties: [ObjcProperty]
}

public extension ObjcCategory {
    /// 分类实现的所有协议
    var allProtocols: [String] {
        var protocols: Set<String> = []
        var child: [String] = self.protocols
        //
        var addedProtocols: Set<String> = []
        //
        while !child.isEmpty {
            let count = child.count
            for protocolname in child {
                if let objcProtocol = APP.shared.protolist[protocolname] {
                    for protocolName in objcProtocol.protocols where !addedProtocols.contains(protocolName) {
                        child.append(protocolName)
                        addedProtocols.insert(protocolName)
                    }
                }
                //
                protocols.insert(protocolname)
            }
            //
            child.removeFirst(count)
        }
        //
        return Array(protocols)
    }
}

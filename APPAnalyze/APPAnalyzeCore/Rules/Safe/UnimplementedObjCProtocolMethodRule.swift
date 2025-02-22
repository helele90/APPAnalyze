//
//  UnimplementedObjCProtocolMethodRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/4/25.
//

import Foundation

struct UnimplementedObjCProtocolMethodIssueItem: Encodable {
    let className: String
    let protocolName: String
    let instanceMethods: [String]
    let classMethods: [String]

    enum CodingKeys: String, CodingKey {
        case `class`
        case `protocol`
        case instanceMethods
        case classMethods
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(className, forKey: .class)
        try container.encode(protocolName, forKey: .protocol)
        if !instanceMethods.isEmpty {
            try container.encode(instanceMethods, forKey: .instanceMethods)
        }
        if !classMethods.isEmpty {
            try container.encode(classMethods, forKey: .classMethods)
        }
    }
}

struct UnimplementedObjCProtocolMethodIssue: IIssue {
    let name: String = "UnimplementedObjCProtocolMethod"

    let module: String

    let severity: Severity = .error

    let info: [UnimplementedObjCProtocolMethodIssueItem]

    let message: String = "未实现的ObjC协议方法"

    let type: IssueType = .safe
}

/// 扫描检查未实现协议的非可选方法
/// 方法没有实现可能会导致功能异常或崩溃
enum UnimplementedObjCProtocolMethodRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [UnimplementedObjCProtocolMethodIssue] = []
        for component in components {
            //
            var items: [UnimplementedObjCProtocolMethodIssueItem] = []
            // 扫描遍历所有的类
            for library in component.libraries {
                for className in library.classlist {
                    guard let objcClass = APP.shared.classlist[className] else {
                        log("类不存在\(className)")
                        continue
                    }

                    var protocols = Set(objcClass.protocols)
                    // 移除父类实现的协议
                    if let superObjcClass = objcClass.superclass {
                        protocols = protocols.subtracting(superObjcClass.allProtocols)
                    }
                    // 遍历类实现的协议
                    for protocolName in protocols {
                        guard let objcProtocol = APP.shared.protolist[protocolName] else {
                            log("未找到协议-\(className)-\(protocolName)")
                            continue
                        }

                        // 检查类是否实现了所有协议的非可选方法
                        var unimplementedInstanceMethods = objcProtocol.instanceMethods.filter { !objcClass.instanceMethods.contains($0) }
                        var unimplementedClassMethods = objcProtocol.classMethods.filter { !objcClass.classMethods.contains($0) }
                        if unimplementedInstanceMethods.isEmpty && unimplementedClassMethods.isEmpty {
                            continue
                        }
                        // 过滤类的分类方法
                        if let categorylist = APP.shared.categorylist[objcClass.name] {
                            for objcCategory in categorylist {
                                unimplementedInstanceMethods = unimplementedInstanceMethods.filter { !objcCategory.instanceMethods.contains($0) }
                                unimplementedClassMethods = unimplementedClassMethods.filter { !objcCategory.classMethods.contains($0) }
                            }
                        }
                        //
                        if !unimplementedInstanceMethods.isEmpty || !unimplementedClassMethods.isEmpty {
                            let item = UnimplementedObjCProtocolMethodIssueItem(className: objcClass.name, protocolName: protocolName, instanceMethods: unimplementedInstanceMethods, classMethods: unimplementedClassMethods)
                            items.append(item)
                        }
                    }
                }
            }
            //
            if !items.isEmpty {
                let issue = UnimplementedObjCProtocolMethodIssue(module: component.name, info: items)
                issues.append(issue)
            }
        }
        return issues
    }
}

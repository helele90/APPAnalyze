//
//  UnusedObjCMethodRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct UnusedObjCMethodItem: Encodable {
    let className: String
    let instanceMethods: [String]
    let classMethods: [String]

    enum CodingKeys: String, CodingKey {
        case `class`
        case instanceMethods
        case classMethods
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(className, forKey: .class)
        if !instanceMethods.isEmpty {
            try container.encode(instanceMethods, forKey: .instanceMethods)
        }
        if !classMethods.isEmpty {
            try container.encode(classMethods, forKey: .classMethods)
        }
    }
}

struct UnusedObjCMethodIssue: IIssue {
    let name: String = "UnusedObjCMethod"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedObjCMethodItem]

    let message: String = "未使用的ObjC方法"

    let type: IssueType = .size
}

struct UnusedObjCMethodRuleConfig {
    let excludeInstanceMethods: Set<String>
    let excludeClassMethods: Set<String>
    let excludeInstanceMethodRegex: [String]
    let excludeClassMethodRegex: [String]
    let excludeProtocols: Set<String>
}

extension Configuration {
    var unusedObjCMethodRule: UnusedObjCMethodRuleConfig {
        var excludeInstanceMethods = Set(rules?["unusedObjCMethod"]["excludeInstanceMethods"].arrayObject as? [String] ?? [])
        excludeInstanceMethods.insert(".cxx_destruct")
        //
        var excludeClassMethods = Set(rules?["unusedObjCMethod"]["excludeClassMethods"].arrayObject as? [String] ?? [])
        excludeClassMethods.insert("load")
        excludeClassMethods.insert("initialize")
        //
        let excludeInstanceMethodRegex = rules?["unusedObjCMethod"]["excludeInstanceMethodRegex"].arrayObject as? [String] ?? []
        //
        let excludeClassMethodRegex = rules?["unusedObjCMethod"]["excludeClassMethodRegex"].arrayObject as? [String] ?? []
        //
        let excludeProtocols = Set(rules?["unusedObjCMethod"]["excludeProtocols"].arrayObject as? [String] ?? [])
        //
        return UnusedObjCMethodRuleConfig(excludeInstanceMethods: excludeInstanceMethods, excludeClassMethods: excludeClassMethods, excludeInstanceMethodRegex: excludeInstanceMethodRegex, excludeClassMethodRegex: excludeClassMethodRegex, excludeProtocols: excludeProtocols)
    }
}

/// 检查未使用的方法。
/// 减少包大小
enum UnusedObjCMethodRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        //
        let config = APPAnalyze.shared.config.unusedObjCMethodRule
        let excludeInstanceMethods = config.excludeInstanceMethods
        let excludeClassMethods = config.excludeClassMethods
        let excludeInstanceMethodRegex = config.excludeInstanceMethodRegex
        let excludeClassMethodRegex = config.excludeClassMethodRegex
        let excludeProtocols = config.excludeProtocols
        //
        var issues: [UnusedObjCMethodIssue] = []
        //
        let hasMJ = APP.shared.protolist["MJKeyValue"] != nil
        //
        for component in components {
            let name = component.name
            // 已使用的类实例方法
            var selRefs: Set<String> = Set(component.libraries.flatMap { $0.selrefs })
            var usedStrings: Set<String> = Set(component.libraries.flatMap { $0.usedStrings })
            // 依赖当前库的其他库的方法列表
            for otherComponent in components where otherComponent.name != component.name {
                if otherComponent.allDependencies.contains(component.name) {
                    for library in otherComponent.libraries {
                        selRefs = selRefs.union(library.selrefs)
                        usedStrings = selRefs.union(library.usedStrings)
                    }
                }
            }
            //
            let classlist = component.libraries.flatMap { $0.classlist }
            //
            var unusedMethods: [UnusedObjCMethodItem] = []
            //
            for className in classlist {
                guard let objcClass = APP.shared.classlist[className] else {
                    log(className)
                    continue
                }

                // RCT前缀
                if !excludeProtocols.isDisjoint(with: objcClass.allProtocols) {
                    continue
                }
                //
                var classInstanceMethods = Set(objcClass.instanceMethods)
                var classClassMethods = Set(objcClass.classMethods)
                // 移除已使用的方法
                classInstanceMethods = classInstanceMethods.filter { !selRefs.contains($0) }
                classClassMethods = classClassMethods.filter { !selRefs.contains($0) }
                // 移除需要忽略的方法
                classInstanceMethods.subtract(excludeInstanceMethods)
                classClassMethods.subtract(excludeClassMethods)
                // 添加实例属性get/set方法
                for property in objcClass.instanceProperties {
                    let name = property.name
                    // get 方法
                    classInstanceMethods.remove(name)
                    // set 方法
                    let set = MachoTool.mapSetterMethod(name: name)
                    classInstanceMethods.remove(set)
                }
                // 过滤使用字符串调用的方法
                classInstanceMethods = classInstanceMethods.filter { !usedStrings.contains($0) }
                classClassMethods = classClassMethods.filter { !usedStrings.contains($0) }
                // 提前退出提高性能
                if classInstanceMethods.isEmpty && classClassMethods.isEmpty {
                    continue
                }
                // 遍历所有父类
                for className in objcClass.allSuperClass {
                    // 过滤父类方法
                    if let objcClass = APP.shared.classlist[className] {
                        classInstanceMethods.subtract(objcClass.instanceMethods)
                        classClassMethods.subtract(objcClass.classMethods)
                        // 添加实例属性get/set方法
                        for property in objcClass.instanceProperties {
                            let name = property.name
                            // get 方法
                            classInstanceMethods.remove(name)
                            // set 方法
                            let set = MachoTool.mapSetterMethod(name: name)
                            classInstanceMethods.remove(set)
                        }
                    } else {
                        log("未找到类\(className)")
                    }
                    // 移除分类方法
                    if let categorylist = APP.shared.categorylist[className] {
                        for category in categorylist {
                            classInstanceMethods.subtract(category.instanceMethods)
                            let categoryInstanceProperties = category.instanceProperties.map { $0.name }
                            classInstanceMethods.subtract(categoryInstanceProperties)
                            //
                            classClassMethods.subtract(category.classMethods)
                        }
                    }
                }
                // 提前退出提高性能
                if classInstanceMethods.isEmpty && classClassMethods.isEmpty {
                    continue
                }
                // 过滤协议方法
                var allProtocols = objcClass.allProtocols
                // MJ 适配
                allProtocols.append("NSCoding")
                if hasMJ {
                    allProtocols.append("MJKeyValue")
                }
                //
                for protocolName in allProtocols {
                    if let proto = APP.shared.protolist[protocolName] {
                        classInstanceMethods.subtract(proto.instanceMethods)
                        classClassMethods.subtract(proto.classMethods)
                        classInstanceMethods.subtract(proto.optionalInstanceMethods)
                        classClassMethods.subtract(proto.optionalClassMethods)
                    } else {
                        log("\(className)_\(protocolName)-协议不存在")
                    }
                }
                // 正则表达式过滤
                classInstanceMethods = classInstanceMethods.filter { method in
                    for regex in excludeInstanceMethodRegex {
                        let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                        if RE?.firstMatch(in: method, range: NSRange(location: 0, length: method.count)) != nil {
                            return false
                        }
                    }

                    return true
                }
                classClassMethods = classClassMethods.filter { method in
                    for regex in excludeClassMethodRegex {
                        let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                        if RE?.firstMatch(in: method, range: NSRange(location: 0, length: method.count)) != nil {
                            return false
                        }
                    }

                    return true
                }
                //
                if !classInstanceMethods.isEmpty || !classClassMethods.isEmpty {
                    let unusedMethod = UnusedObjCMethodItem(className: className, instanceMethods: Array(classInstanceMethods), classMethods: Array(classClassMethods))
                    unusedMethods.append(unusedMethod)
                }
            }
            //
            if !unusedMethods.isEmpty {
                let issue = UnusedObjCMethodIssue(module: name, info: unusedMethods)
                issues.append(issue)
            }
        }

        return issues
    }
    
}

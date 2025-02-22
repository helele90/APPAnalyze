//
//  UnusedClassRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

public struct UnusedClassIssue: IIssue {
    public let name: String = "UnusedClass"

    public let module: String

    public let severity: Severity = .warning

    public let info: [String]

    public let message: String = "未使用的类"

    public let type: IssueType = .size
    
}

struct UnusedClassRuleConfig {
    /// 过滤 Swift 类
    let swiftEnable: Bool
    /// 排除实现的父类
    let excludeSuperClass: Set<String>

    /// 排除实现的协议
    let excludeProtocols: Set<String>

    let excludeClassRegex: [String]
}

extension Configuration {
    var unusedClassRule: UnusedClassRuleConfig {
        let swiftEnable = rules?["unusedClass"]["swiftEnable"].bool ?? false
        let excludeSuperClass = Set(rules?["unusedClass"]["excludeSuperClasslist"].arrayObject as? [String] ?? [])
        let excludeProtocols = Set(rules?["unusedClass"]["excludeProtocols"].arrayObject as? [String] ?? [])
        let excludeClassRegex = rules?["unusedClass"]["excludeClassRegex"].arrayObject as? [String] ?? []
        return UnusedClassRuleConfig(swiftEnable: swiftEnable, excludeSuperClass: excludeSuperClass, excludeProtocols: excludeProtocols, excludeClassRegex: excludeClassRegex)
    }
}

/// 检查未使用的类
///
/// 扫描所有未使用的类
public enum UnusedClassRule: Rule {
    public static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [UnusedClassIssue] = []
        // 读取配置
        let config = APPAnalyze.shared.config.unusedClassRule
        let swiftEnable = config.swiftEnable
        let excludeSuperClass: Set<String> = config.excludeSuperClass
        let excludeProtocols: Set<String> = config.excludeProtocols
        let excludeClassRegex: [String] = config.excludeClassRegex
        // 获取所有被当做属性使用的类型、所有被引用的类、所有被继承的父类、所有被使用的字符串
        var allIvarTypeRefs: Set<String> = []
        var allSuperrefs: Set<String> = []
        var allClassrefs: Set<String> = []
        var allUsedStrings: Set<String> = []
        for component in components {
            for library in component.libraries {
                allIvarTypeRefs = allIvarTypeRefs.union(library.objcIvarTypeRefs)
                allSuperrefs = allSuperrefs.union(library.superrefs)
                allClassrefs = allClassrefs.union(library.classrefs)
                allUsedStrings = allUsedStrings.union(library.usedStrings)
            }
        }
        // 遍历所有组件
        for component in components {
            let classlist = component.libraries.flatMap { $0.classlist }
            let unusedClass = classlist.filter { className -> Bool in
                guard let objcClass = APP.shared.classlist[className] else {
                    log("未找到类:\(className)")
                    return false
                }
                // 是否被引用
                if allClassrefs.contains(className) {
                    return false
                }
                // 未实现 load 方法
                if objcClass.isLoadclass {
                    return false
                }
                // 未被继承
                if allSuperrefs.contains(className) {
                    return false
                }
                #warning("对于类来讲，可能存在定义了属性但是未使用")
                // 是否被作为属性使用
                if allIvarTypeRefs.contains(className) {
                    return false
                }
                // 检查是否有字符串调用
                #warning("swift 类都有字符串存在")
                if allUsedStrings.contains(className) {
                    return false
                }
                // 屏蔽父类
                let allSuperClass = objcClass.allSuperClass
                if !excludeSuperClass.isDisjoint(with: allSuperClass) {
                    return false
                }
                // 屏蔽协议
                let allProtocols = objcClass.allProtocols
                if !excludeProtocols.isDisjoint(with: allProtocols) {
                    return false
                }
                // 未开启 Swift 检查过滤 Swift 类
                if !swiftEnable && objcClass.isSwiftClass {
                    return false
                }
                // 正则表达式过滤类名
                for regex in excludeClassRegex {
                    let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                    if RE?.firstMatch(in: className, range: NSRange(location: 0, length: className.count)) != nil {
                        return false
                    }
                }
                return true
            }
            //
            if !unusedClass.isEmpty {
                let issue = UnusedClassIssue(module: component.name, info: unusedClass)
                issues.append(issue)
            }
        }
        return issues
    }
}

//
//  GlobalUnusedComponentRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct GlobalUnusedModuleIssue: IIssue {
    let name: String = "GlobalUnusedModuleRule"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "组件未被使用"

    let type: IssueType = .size
}

public struct GlobalUnusedModuleRuleConfig {
    public let enable: Bool
    public let excludeModules: Set<String>
}

public extension Configuration {
    var globalUnusedModuleRule: GlobalUnusedModuleRuleConfig {
        let enable = rules?["globalUnusedModule"]["enable"].bool ?? true
        let excludeModules = Set(rules?["globalUnusedModule"]["excludeModules"].arrayObject as? [String] ?? [])
        return GlobalUnusedModuleRuleConfig(enable: enable, excludeModules: excludeModules)
    }
}

/// 检查组件未被使用到。例如没有使用到此组件的资源，类，协议
public enum GlobalUnusedModuleRule: Rule {
    public static func check() async -> [any IIssue] {
        // 读取配置
        let config = APPAnalyze.shared.config.globalUnusedModuleRule
        guard config.enable else {
            return []
        }
        //
        let excludeModules = config.excludeModules
        //
        let components = APP.shared.modules
        // 所有被依赖的组件
        var allDependencies: Set<String> = []
        var allUsedClassStrings: Set<String> = []
        for component in components {
            // 过滤主工程
            if component.name != APP.shared.mainModule {
                allDependencies = allDependencies.union(component.dependencies)
            }
            // 和类名一样的字符串
            for library in component.libraries {
                for usedString in library.usedStrings {
                    if APP.shared.classlist[usedString] != nil {
                        allUsedClassStrings.insert(usedString)
                    }
                }
            }
        }
        //
        var unusedModules: Set<String> = []
        //
        var issues: [GlobalUnusedModuleIssue] = []
        for component in components {
            // 白名单过滤
            if excludeModules.contains(component.name) {
                continue
            }
            //
            var notUsed = true
            for library in component.libraries {
                // 包含 load 方法
                if !library.loadClasses.isEmpty {
                    notUsed = false
                    break
                }
            }
            // 移除自己模块的类
            var otherUsedClassStrings = allUsedClassStrings
            for library in component.libraries {
                otherUsedClassStrings.subtract(library.classlist)
            }
            // 判断是否有被动态调用的类
            for library in component.libraries {
                if !otherUsedClassStrings.isDisjoint(with: library.classlist) {
                    notUsed = false
                    break
                }
            }
            //
            if notUsed {
                unusedModules.insert(component.name)
            }
        }
        //
        if !unusedModules.isEmpty {
            let module = APP.shared.mainModule
            let issue = GlobalUnusedModuleIssue(module: module, info: Array(unusedModules))
            issues.append(issue)
        }
        //
        return issues
    }
}

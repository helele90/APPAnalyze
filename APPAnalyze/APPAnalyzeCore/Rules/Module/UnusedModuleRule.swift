//
//  UnusedComponentRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct UnusedModuleIssue: IIssue {
    let name: String = "UnusedModule"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "未使用的子组件依赖"

    let type: IssueType = .module
}

struct UnusedModuleRuleConfig {
    let enable: Bool
    let excludeModules: Set<String>
}

extension Configuration {
    var unusedModuleRule: UnusedModuleRuleConfig {
        let enable = rules?["unusedModule"]["enable"].bool ?? true
        let excludeModules = Set(rules?["unusedModule"]["excludeModules"].arrayObject as? [String] ?? [])
        return UnusedModuleRuleConfig(enable: enable, excludeModules: excludeModules)
    }
}

/// 未使用到的组件
///
/// 依赖了某个组件，但是并未使用到组件的`API`
/// - Warning: 无法判断C语言宏的依赖
public enum UnusedModuleRule: Rule {
    public static func check() async -> [any IIssue] {
        // 读取配置
        let config = APPAnalyze.shared.config.unusedModuleRule
        guard config.enable else {
            return []
        }
        //
        let excludeModules = config.excludeModules
        //
        let components = APP.shared.modules
        var issues: [UnusedModuleIssue] = []
        for component in components {
            // 过滤主工程
            if component.name == APP.shared.mainModule {
                continue
            }
            
            var unusedModules: Set<String> = []
            // 所有使用的类
            var usedClasslist: Set<String> = []
            // 所有使用的协议
            var usedProtolist: Set<String> = []
            //
            var usedSymbols: Set<String> = []
            //
            var usedSels: Set<String> = []
            for library in component.libraries {
                // 类被直接引用
                usedClasslist = usedClasslist.union(library.classrefs)
                // 类被当做父类继承
                usedClasslist = usedClasslist.union(library.superrefs)
                // 类被当做父类继承
                usedClasslist = usedClasslist.union(library.objcIvarTypeRefs)
                // 使用的协议
                usedProtolist = usedProtolist.union(library.usedProtolist)
                // 使用的符号
                usedSymbols = usedSymbols.union(library.usedSymbols)
                // 使用的 ObjC 方法
                usedSels = usedSels.union(library.selrefs)
            }
            //
            for childComponent in components where component.dependencies.contains(childComponent.name) {
                // 过滤白名单组件
                if excludeModules.contains(childComponent.name) {
                    continue
                }
                //
                var notUsed = true
                //
                for library in childComponent.libraries {
                    // 有类被使用到
                    if !usedClasslist.isDisjoint(with: library.classlist) {
                        notUsed = false
                        break
                    }
                    // 有协议被使用到
                    if !usedProtolist.isDisjoint(with: library.protolist) {
                        notUsed = false
                        break
                    }
                    // 有符号被使用到
                    let symbols = Set(library.symbols.keys)
                    if !usedSymbols.isDisjoint(with: symbols) {
                        notUsed = false
                        break
                    }
                    // 使用了组件的 category 方法
                    for category in library.catlist {
                        if usedClasslist.contains(category.cls) {
                            if !usedSels.isDisjoint(with: category.instanceMethods) || !usedSels.isDisjoint(with: category.classMethods) {
                                notUsed = false
                                break
                            }
                        }
                    }
                }
                //
                if notUsed {
                    unusedModules.insert(childComponent.name)
                }
            }
            //
            if !unusedModules.isEmpty {
                let issue = UnusedModuleIssue(module: component.name, info: Array(unusedModules))
                issues.append(issue)
            }
        }

        return issues
    }
}

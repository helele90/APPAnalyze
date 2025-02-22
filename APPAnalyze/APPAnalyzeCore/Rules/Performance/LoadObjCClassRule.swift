//
//  LoadObjCClassRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct LoadObjCClassIssue: IIssue {
    let name: String = "LoadObjCClass"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "实现+load方法的ObjC类"

    let type: IssueType = .performance
}

struct LoadObjCClassRuleConfig {
    /// 排除实现的父类
    let excludeSuperClass: Set<String>

    /// 排除实现的协议
    let excludeProtocols: Set<String>
}

extension Configuration {
    var loadClassRule: LoadObjCClassRuleConfig {
        let excludeSuperClass = Set(rules?["loadObjCClass"]["excludeSuperClasslist"].arrayObject as? [String] ?? [])
        let excludeProtocols = Set(rules?["loadObjCClass"]["excludeProtocols"].arrayObject as? [String] ?? [])
        return LoadObjCClassRuleConfig(excludeSuperClass: excludeSuperClass, excludeProtocols: excludeProtocols)
    }
}

/// 扫描实现`+load`方法的ObjC类。
/// 减少实现`+load`提高冷启动速度
enum LoadObjCClassRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        // 读取配置
        let config = APPAnalyze.shared.config.loadClassRule
        let excludeProtocols = config.excludeProtocols
        let excludeSuperClass = config.excludeSuperClass
        //
        var issues: [LoadObjCClassIssue] = []
        // 扫描遍历所有的类
        for component in components {
            var loadClasslist: [String] = []
            //
            for module in component.libraries {
                let classlist = module.loadClasses
                for className in classlist {
                    // 未找到对应的类
                    guard let objcClass = APP.shared.classlist[className] else {
                        log("未找到类:\(className)")
                        continue
                    }

                    // 过滤协议白名单
                    if !excludeProtocols.isEmpty {
                        let allProtocols = Set(objcClass.allProtocols)
                        if !allProtocols.isDisjoint(with: excludeProtocols) {
                            continue
                        }
                    }
                    // 过滤父类白名单
                    if !excludeSuperClass.isEmpty {
                        let allSuperClass = Set(objcClass.allSuperClass)
                        if !allSuperClass.isDisjoint(with: excludeSuperClass) {
                            continue
                        }
                    }
                    //
                    loadClasslist.append(className)
                }
            }
            //
            if !loadClasslist.isEmpty {
                let issue = LoadObjCClassIssue(module: component.name, info: loadClasslist)
                issues.append(issue)
            }
        }

        return issues
    }
}

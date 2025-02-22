//
//  DynamicUseObjCClassRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct DynamicUseObjCClassIssue: IIssue {
    let name: String = "DynamicUseObjCClass"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "字符串反射调用ObjC类"

    let type: IssueType = .safe
}

struct DynamicCallObjCClassRuleConfig {
    let enable: Bool
    let excludeClasslist: Set<String>
}

extension Configuration {
    var dynamicCallClassRule: DynamicCallObjCClassRuleConfig {
        let enable = rules?["dynamicCallObjCClass"]["enable"].bool ?? true
        let excludeClasslist = Set(rules?["dynamicCallObjCClass"]["excludeClasslist"].arrayObject as? [String] ?? [])
        return DynamicCallObjCClassRuleConfig(enable: enable, excludeClasslist: excludeClasslist)
    }
}

#warning("待修复，Swift类误报问题")

/// 扫描通过字符串反射调用其他类。
/// 动态调用存在一定的风险无法利用编译检查
enum DynamicUseObjCClassRule: Rule {
    static func check() async -> [any IIssue] {
        let config = APPAnalyze.shared.config.dynamicCallClassRule
        // 是否开启
        guard config.enable else {
            return []
        }
        //
        let components = APP.shared.modules
        var issues: [DynamicUseObjCClassIssue] = []
        //
        let excludeClasslist = config.excludeClasslist
        // 扫描遍历所有使用的字符串
        for component in components {
            var classlist: [String] = []
            //
            for library in component.libraries {
                for string in library.usedStrings {
                    // 字符串对应的类名存在
                    guard APP.shared.classlist[string] != nil else {
                        continue
                    }

                    // 白名单过滤
                    if excludeClasslist.contains(string) {
                        continue
                    }

                    classlist.append(string)
                }
            }
            //
            if !classlist.isEmpty {
                let name = component.name
                let issue = DynamicUseObjCClassIssue(module: name, info: classlist)
                issues.append(issue)
            }
        }

        return issues
    }
}

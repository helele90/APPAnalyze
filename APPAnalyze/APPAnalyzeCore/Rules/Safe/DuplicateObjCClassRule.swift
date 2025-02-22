//
//  DuplicateClassRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/4/11.
//

import Foundation

struct DuplicateObjCClassIssueItem: Encodable {
    let `class`: String
    let frameworks: [String]
}

struct DuplicateObjCClassIssue: IIssue {
    let name: String = "DuplicateObjCClass"

    let module: String

    let severity: Severity = .error

    let info: [DuplicateObjCClassIssueItem]

    let message: String = "重复的ObjC类"

    let type: IssueType = .safe
}

/// 静态库和动态库有重复类符号。
/// 不安全同时会增加包体积
enum DuplicateObjCClassRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        // 类名和 framework 映射
        var classNameAndFrameworkMap: [String: Set<String>] = [:]
        // 扫描遍历所有的类
        for component in components {
            for library in component.libraries {
                let frameworkName = library.name
                for className in library.classlist {
                    if var frameworks = classNameAndFrameworkMap[className] {
                        frameworks.insert(frameworkName)
                        classNameAndFrameworkMap[className] = frameworks
                    } else {
                        classNameAndFrameworkMap[className] = Set([frameworkName])
                    }
                }
            }
        }
        // 检查同一个类名出现在2个framework中
        let items: [DuplicateObjCClassIssueItem] = classNameAndFrameworkMap.filter { $0.value.count > 1 }.map { DuplicateObjCClassIssueItem(class: $0.key, frameworks: Array($0.value)) }
        if items.isEmpty {
            return []
        }

        let issue = DuplicateObjCClassIssue(module: APP.shared.mainModule, info: items)
        return [issue]
    }
}

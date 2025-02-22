//
//  DuplicateCategoryMethodsRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct DuplicateCategoryMethodsRuleIssue: IIssue {
    let name: String = "DuplicateCategoryMethods"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedCategoryMethodItem]

    let message: String = "重复的分类方法"

    let type: IssueType = .safe
}

/// 检查分类中和原始类同样的方法。
/// 可能导致一些潜在的风险
enum DuplicateCategoryMethodsRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [DuplicateCategoryMethodsRuleIssue] = []
        for component in components {
            for machoModule in component.libraries {
                var items: [UnusedCategoryMethodItem] = []
                // 遍历所有分类
                for category in machoModule.catlist {
                    //
                    let className = category.cls
                    guard let objcclass = APP.shared.classlist[className] else {
                        log("未找到类-\(category.cls)")
                        continue
                    }
                    //
                    let categoryInstanceMethods = Set(category.instanceMethods)
                    let categoryClassMethods = Set(category.classMethods)
                    var sameInstanceMethods = categoryInstanceMethods.intersection(objcclass.instanceMethods)
                    var sameClassMethods = categoryClassMethods.intersection(objcclass.classMethods)
                    // 遍历所有父类
                    for superClass in objcclass.allSuperClass {
                        guard let objcclass = APP.shared.classlist[className] else {
                            log("未找到类\(superClass)")
                            continue
                        }
                        // 实例方法
                        for method in objcclass.instanceMethods {
                            if categoryInstanceMethods.contains(method) {
                                sameInstanceMethods.insert(method)
                            }
                        }
                        // 类方法
                        for method in objcclass.classMethods {
                            if categoryClassMethods.contains(method) {
                                sameClassMethods.insert(method)
                            }
                        }
                    }
                    // 过滤load/initialize方法
                    sameClassMethods.remove("load")
                    sameClassMethods.remove("initialize")
                    //
                    if !sameInstanceMethods.isEmpty || !sameClassMethods.isEmpty {
                        let item = UnusedCategoryMethodItem(name: category.name, className: category.cls, instanceMethods: Array(sameInstanceMethods), classMethods: Array(sameClassMethods))
                        items.append(item)
                    }
                }

                //
                if !items.isEmpty {
                    let name = component.name
                    let issue = DuplicateCategoryMethodsRuleIssue(module: name, info: items)
                    issues.append(issue)
                }
            }
        }
        return issues
    }
}

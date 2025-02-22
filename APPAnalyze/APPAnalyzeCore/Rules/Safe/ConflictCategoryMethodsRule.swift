//
//  ConflictCategoryMethodsRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct ConflictCategoryMethod: Encodable {
    let `class`: String
    let methodName: String
    let items: [ConflictCategoryMethodItem]
}

struct ConflictCategoryMethodsRuleIssue: IIssue {
    let name: String = "ConflictCategoryMethods"

    let module: String

    let severity: Severity = .error

    let info: [ConflictCategoryMethod]

    let message: String = "冲突的分类方法"

    let type: IssueType = .safe
}

private struct Key {
    let cls: String
    let method: String
}

extension Key: Hashable {}

struct ConflictCategoryMethodItem: Encodable {
    let module: String
    let name: String
}

/// 检查分类方法重名冲突。
/// 同一个类的多个分类中存在同样的方法，有一定的风险
enum ConflictCategoryMethodsRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [ConflictCategoryMethodsRuleIssue] = []
        //
        var instanceMethods: [Key: [ConflictCategoryMethodItem]] = [:]
        var classMethods: [Key: [ConflictCategoryMethodItem]] = [:]
        //
        for component in components {
            for library in component.libraries {
                let catlist = library.catlist
                //
                var addIndexes: Set<Int> = []
                //
                for (index, category) in catlist.enumerated() {
                    if addIndexes.contains(index) {
                        continue
                    }
                    //
                    let cls = category.cls
                    // 实例方法
                    for method in category.instanceMethods {
                        let key = Key(cls: cls, method: method)
                        if var names = instanceMethods[key] {
                            names.append(ConflictCategoryMethodItem(module: component.name, name: category.name))
                            instanceMethods[key] = names
                        } else {
                            instanceMethods[key] = [ConflictCategoryMethodItem(module: component.name, name: category.name)]
                        }
                    }
                    // 类方法
                    for method in category.classMethods {
                        // 过滤 load/initialize 方法
                        if method == "load" || method == "initialize" {
                            continue
                        }

                        let key = Key(cls: cls, method: method)
                        if var names = classMethods[key] {
                            names.append(ConflictCategoryMethodItem(module: component.name, name: category.name))
                            classMethods[key] = names
                        } else {
                            classMethods[key] = [ConflictCategoryMethodItem(module: component.name, name: category.name)]
                        }
                    }

                    // 最后一个位置直接退出
                    if index == catlist.count - 1 {
                        continue
                    }
                    //
                    addIndexes.insert(index)
                    // 遍历扫描此分类对应的类的其他分类方法
                    for index2 in index + 1 ..< catlist.count {
                        //
                        if addIndexes.contains(index2) {
                            continue
                        }

                        let category2 = catlist[index2]
                        // 同一个类的分类
                        if cls != category2.cls {
                            continue
                        }

                        // 实例方法
                        for method in category2.instanceMethods {
                            let key = Key(cls: cls, method: method)
                            if var names = instanceMethods[key] {
                                names.append(ConflictCategoryMethodItem(module: component.name, name: category2.name))
                                instanceMethods[key] = names
                            } else {
                                instanceMethods[key] = [ConflictCategoryMethodItem(module: component.name, name: category2.name)]
                            }
                        }

                        // 类方法
                        for method in category2.classMethods {
                            // 过滤 load/initialize 方法
                            if method == "load" || method == "initialize" {
                                continue
                            }

                            let key = Key(cls: cls, method: method)
                            if var names = classMethods[key] {
                                names.append(ConflictCategoryMethodItem(module: component.name, name: category2.name))
                                classMethods[key] = names
                            } else {
                                classMethods[key] = [ConflictCategoryMethodItem(module: component.name, name: category2.name)]
                            }
                        }
                        //
                        addIndexes.insert(index2)
                    }
                }
            }
        }
        //
        var items: [ConflictCategoryMethod] = []
        // 实例方法
        for (key, value) in instanceMethods where value.count > 1 {
            let methodName = "-\(key.method)"
            let item = ConflictCategoryMethod(class: key.cls, methodName: methodName, items: value)
            items.append(item)
        }
        // 类方法
        for (key, value) in classMethods where value.count > 1 {
            let methodName = "+\(key.method)"
            let item = ConflictCategoryMethod(class: key.cls, methodName: methodName, items: value)
            items.append(item)
        }
        //
        if !items.isEmpty {
            let issue = ConflictCategoryMethodsRuleIssue(module: APP.shared.mainModule, info: items)
            issues.append(issue)
        }
        return issues
    }
}

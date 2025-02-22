//
//  UnusedCategoryMethodsRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct UnusedCategoryMethodsIssue: IIssue {
    let name: String = "UnusedCategoryMethods"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedCategoryMethodItem]

    let message: String = "未使用的分类方法"

    let type: IssueType = .size
}

/// 检查未使用的分类方法。减少包大小
enum UnusedCategoryMethodsRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [UnusedCategoryMethodsIssue] = []
        //
        for component in components {
            let moduleName = component.name
            var items: [UnusedCategoryMethodItem] = []
            //
            let catlist = component.libraries.flatMap { $0.catlist }
            // 当前库使用的方法列表
            var selrefs: Set<String> = Set(component.libraries.flatMap { $0.selrefs })
            // 依赖当前库的其他库的方法列表
            for otherComponent in components where otherComponent.name != component.name {
                if otherComponent.allDependencies.contains(component.name) {
                    for library in otherComponent.libraries {
                        selrefs = selrefs.union(library.selrefs)
                    }
                }
            }
            //
            for category in catlist {
                var unusedInstanceMethods: Set<String> = Set(category.instanceMethods)
                var unusedClassMethods: Set<String> = Set(category.classMethods)
                unusedClassMethods = unusedClassMethods.filter { !selrefs.contains($0) }
                unusedInstanceMethods = unusedInstanceMethods.filter { !selrefs.contains($0) }
                //
                unusedInstanceMethods.remove("observeValueForKeyPath:ofObject:change:context:")
                //
                unusedClassMethods.remove("load")
                unusedClassMethods.remove("initialize")
                // 提前退出
                if unusedInstanceMethods.isEmpty && unusedClassMethods.isEmpty {
                    continue
                }
                //
                // 过滤原始类实现的协议中定义的实例方法和类方法
                let className = category.cls
                // 过滤原始类实现的协议中定义的方法
                if let objcClass = APP.shared.classlist[className] {
                    // 过滤原始类的方法
                    unusedInstanceMethods.subtract(objcClass.instanceMethods)
                    unusedClassMethods.subtract(objcClass.classMethods)
                    // 过滤父类的方法
                    for superClassName in objcClass.allSuperClass {
                        if let objcSuperClass = APP.shared.classlist[superClassName] {
                            unusedInstanceMethods.subtract(objcSuperClass.instanceMethods)
                            unusedClassMethods.subtract(objcSuperClass.classMethods)
                        }
                        // 过滤父类的category
                        if let categorylist = APP.shared.categorylist[superClassName] {
                            for objcCategory in categorylist {
                                unusedInstanceMethods.subtract(objcCategory.instanceMethods)
                                unusedClassMethods.subtract(objcCategory.classMethods)
                            }
                        }
                    }
                    //
                    for protocolName in objcClass.allProtocols {
                        if let objcProtocol = APP.shared.protolist[protocolName] {
                            unusedInstanceMethods.subtract(objcProtocol.instanceMethods)
                            unusedClassMethods.subtract(objcProtocol.classMethods)
                            unusedInstanceMethods.subtract(objcProtocol.optionalInstanceMethods)
                            unusedClassMethods.subtract(objcProtocol.optionalClassMethods)
                        } else {
                            log("未找到协议\(protocolName)")
                        }
                    }
                } else {
                    log("未找到类-\(category.cls)")
                }
                // 提前退出
                if unusedInstanceMethods.isEmpty && unusedClassMethods.isEmpty {
                    continue
                }
                // 过滤分类实现的协议中定义的方法
                for protocolName in category.allProtocols {
                    if let objcProtocol = APP.shared.protolist[protocolName] {
                        unusedInstanceMethods.subtract(objcProtocol.instanceMethods)
                        unusedClassMethods.subtract(objcProtocol.classMethods)
                        unusedInstanceMethods.subtract(objcProtocol.optionalInstanceMethods)
                        unusedClassMethods.subtract(objcProtocol.optionalClassMethods)
                    } else {
                        log("未找到协议\(protocolName)")
                    }
                }
                //
                if !unusedClassMethods.isEmpty || !unusedInstanceMethods.isEmpty {
                    let item = UnusedCategoryMethodItem(name: category.name, className: category.cls, instanceMethods: Array(unusedInstanceMethods), classMethods: Array(unusedClassMethods))
                    items.append(item)
                }
            }
            //
            if !items.isEmpty {
                let issue = UnusedCategoryMethodsIssue(module: moduleName, info: items)
                issues.append(issue)
            }
        }
        return issues
    }
}

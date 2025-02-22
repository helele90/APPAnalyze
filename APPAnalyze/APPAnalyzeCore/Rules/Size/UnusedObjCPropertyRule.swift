//
//  UnusedObjCPropertyRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/7/17.
//

import Foundation

struct UnusedObjCPropertyIssueItemProperty: Encodable {
    let name: String
    let type: String
}

struct UnusedObjCPropertyIssueItem: Encodable {
    let `class`: String
    let instanceProperties: [UnusedObjCPropertyIssueItemProperty]
}

struct UnusedObjCPropertyIssue: IIssue {
    let name: String = "UnusedObjCProperty"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedObjCPropertyIssueItem]

    let message: String = "未使用的ObjC属性"

    let type: IssueType = .size
}

struct UnusedObjCPropertyRuleConfig {
    let enable: Bool
    let excludeTypes: Set<String>
}

extension Configuration {
    var unusedObjCPropertyRule: UnusedObjCPropertyRuleConfig {
        let enable = rules?["unusedObjCProperty"]["enable"].bool ?? true
        let excludeTypes = Set(rules?["unusedObjCProperty"]["excludeTypes"].arrayObject as? [String] ?? [])
        return UnusedObjCPropertyRuleConfig(enable: enable, excludeTypes: excludeTypes)
    }
}

enum UnusedObjCPropertyRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [UnusedObjCPropertyIssue] = []
        // 过滤 NSObject 的属性
        let ignoreProperties: Set<String> = ["hash", "superclass", "description", "debugDescription"]
        // 读取配置
        let config = APPAnalyze.shared.config.unusedObjCPropertyRule
        let excludeTypes = config.excludeTypes
        let enable = config.enable
        guard enable else {
            return []
        }
        //
        for component in components {
            // 当前库使用的方法列表
            var selRefs: Set<String> = Set(component.libraries.flatMap { $0.selrefs })
            // 依赖当前库的其他库的方法列表
            for otherComponent in components where otherComponent.name != component.name {
                if otherComponent.allDependencies.contains(component.name) {
                    for library in otherComponent.libraries {
                        selRefs = selRefs.union(library.selrefs)
                    }
                }
            }
            for library in component.libraries {
                //
                let classlist = library.classlist
                let objcIvarRefs = library.objcIvarRefs
                //
                var items: [UnusedObjCPropertyIssueItem] = []
                //
                for className in classlist {
                    guard let objcClass = APP.shared.classlist[className] else {
                        log(className)
                        continue
                    }
                    // 遍历类的属性
                    var unusedInstanceProperties: [String: String] = [:]
                    for property in objcClass.instanceProperties {
                        let propertyName = property.name
                        // 过滤属性
                        if ignoreProperties.contains(propertyName) {
                            continue
                        }
                        #warning("先过滤基础类型，后面再完善")
                        if property.type.isEmpty {
                            continue
                        }
                        // 过滤部分属性类型
                        if excludeTypes.contains(property.type) {
                            continue
                        }
                        // 过滤被使用 set/get 的属性
                        let setMethod = MachoTool.mapSetterMethod(name: propertyName)
                        if !selRefs.contains(propertyName) && !selRefs.contains(setMethod) {
                            unusedInstanceProperties[propertyName] = property.type
                        }
                    }

                    // 未使用属性为空提前退出
                    if unusedInstanceProperties.isEmpty {
                        continue
                    }
                    // 过滤接口属性
                    for protocolName in objcClass.allProtocols {
                        if let objcProtocol = APP.shared.protolist[protocolName] {
                            for property in objcProtocol.instanceProperties {
                                unusedInstanceProperties.removeValue(forKey: property.name)
                            }
                        } else {
                            log("未找到协议\(protocolName)")
                        }
                    }
                    // 未使用属性为空提前退出
                    if unusedInstanceProperties.isEmpty {
                        continue
                    }
                    // 过滤所有父类的Category属性
                    for superClassName in objcClass.allSuperClass {
                        if let categorylist = APP.shared.categorylist[superClassName] {
                            for objcCategory in categorylist {
                                for property in objcCategory.instanceProperties {
                                    unusedInstanceProperties.removeValue(forKey: property.name)
                                }
                            }
                        }
                    }
                    //
                    if !objcIvarRefs.isEmpty {
                        for (propertyName, _) in unusedInstanceProperties {
                            let key = ObjCIvarRef(class: className, name: propertyName)
                            if objcIvarRefs.contains(key) {
                                unusedInstanceProperties.removeValue(forKey: propertyName)
                            }
                        }
                    }
                    //
                    if !unusedInstanceProperties.isEmpty {
                        let instanceProperties = unusedInstanceProperties.map { UnusedObjCPropertyIssueItemProperty(name: $0.key, type: $0.value) }
                        let item = UnusedObjCPropertyIssueItem(class: className, instanceProperties: instanceProperties)
                        items.append(item)
                    }
                }
                //
                if !items.isEmpty {
                    let issue = UnusedObjCPropertyIssue(module: component.name, info: items)
                    issues.append(issue)
                }
            }
        }

        return issues
    }

}

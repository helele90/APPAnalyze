////
////  UnusedIvarPropertyRule.swift
////  APPAnalyzeCore
////
////  Created by hexiao on 2023/8/28.
////
//
// import Foundation
//
// struct UnusedObjCIvarIssueItem: Encodable {
//    let `class`: String
//    let instanceIvars: [String]
// }
//
// struct UnusedObjCIvarIssue: IIssue {
//    let name: String = "UnusedObjCIvar"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: [UnusedObjCIvarIssueItem]
//
//    let message: String = "未使用的ObjC Ivar"
//
//    let type: IssueType = .size
// }
//
// struct UnusedObjCIvarRuleConfig {
//    let enable: Bool
// }
//
// extension Configuration {
//    var unusedObjcIvarRule: UnusedObjCIvarRuleConfig {
//        let enable = rules?["unusedObjCIvar"]["enable"].boolValue ?? true
//        return UnusedObjCIvarRuleConfig(enable: enable)
//    }
// }
//
// enum UnusedObjCIvarRule: Rule {
//    static func check() async -> [any IIssue] {
//        let components = APP.shared.components
//        var issues: [UnusedObjCIvarIssue] = []
//        // 读取配置
//        let config = APPAnalyze.shared.config.unusedObjcIvarRule
//        let enable = config.enable
//        guard enable else {
//            return []
//        }
//        //
//        for component in components {
//            for library in component.libraries {
//                //
//                let classlist = library.classlist
//                let objcIvarRefs = library.objcIvarRefs
//                //
//                var unusedIvarItems: [UnusedObjCIvarIssueItem] = []
//                //
//                for className in classlist {
//                    guard let objcClass = APP.shared.classlist[className] else {
//                        log(className)
//                        continue
//                    }
//                    // 遍历类的Ivar
//                    var unusedInstanceIvars: Set<String> = Set(objcClass.ivars)
//                    // 过滤掉属性
//                    for property in objcClass.instanceProperties {
//                        let propertyName = property.name
//                        unusedInstanceIvars.remove(propertyName)
//                    }
//                    //
//                    for ivarName in objcClass.ivars {
//                        let key = ObjCIvarRef(class: className, name: ivarName)
//                        if objcIvarRefs.contains(key) {
//                            unusedInstanceIvars.remove(ivarName)
//                        }
//                    }
//                    //
//                    if !unusedInstanceIvars.isEmpty {
//                        let item = UnusedObjCIvarIssueItem(class: className, instanceIvars: Array(unusedInstanceIvars))
//                        unusedIvarItems.append(item)
//                    }
//                }
//                //
//                if !unusedIvarItems.isEmpty {
//                    let issue = UnusedObjCIvarIssue(module: component.name, info: unusedIvarItems)
//                    issues.append(issue)
//                }
//            }
//        }
//
//        return issues
//    }
//
// }

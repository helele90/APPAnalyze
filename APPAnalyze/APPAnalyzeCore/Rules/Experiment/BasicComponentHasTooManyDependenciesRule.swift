////
////  BasicComponentHasTooManyDependenciesRule.swift
////  APPAnalyze
////
////  Created by hexiao on 2021/11/9.
////
//
//import Foundation
//
//#warning("支持json配置")
//
//private let MaxDependenciesCount = 10
//
//struct BasicComponentHasTooManyDependenciesIssue: IIssue {
//    let name: String = "BasicComponentHasTooManyDependencies"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: String
//
//    let message: String = "基础组件包含太多依赖"
//
//    let type: IssueType = .antiPattern
//}
//
//#warning("支持基础组件和业务组件分开配置")
//
///// 基础组件包含太多依赖。影响业务组件编译、发布速度。需要避免基础组件越来越膨胀，组件之间相互依赖
///// 优化方式：1.减少依赖 2.无法减少依赖的话优化为业务组件
//enum BasicComponentHasTooManyDependenciesRule: Rule {
//    static func check() async -> [any IIssue] {
//        let components = APP.shared.components
//        var issues: [BasicComponentHasTooManyDependenciesIssue] = []
//        for component in components {
//            // 基础组件
//            if component.basic {
//                // 依赖数超过限制
//                if component.allDependenciesCount >= MaxDependenciesCount {
//                    let message = component.allDependencies.joined(separator: ", ")
//                    let issue = BasicComponentHasTooManyDependenciesIssue(module: component.name, info: message)
//                    issues.append(issue)
//                }
//            }
//        }
//        return issues
//    }
//}

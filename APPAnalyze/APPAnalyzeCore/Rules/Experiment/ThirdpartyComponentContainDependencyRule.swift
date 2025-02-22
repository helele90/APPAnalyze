////
////  ThirdpartyComponentContainDependencyRule.swift
////  APPAnalyze
////
////  Created by hexiao on 2021/11/9.
////
//
//import Foundation
//
//struct ThirdpartComponentIssue: IIssue {
//    let name: String = "DynamicUseClass"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: [String]
//
//    let message: String = "第三方库包含依赖"
//
//    let type: IssueType = .antiPattern
//}
//
//struct ThirdpartyComponentContainDependencyRuleConfig {
//    let frameworks: Set<String>
//}
//
//extension Configuration {
//    var thirdpartyComponentContainsDependencyRule: ThirdpartyComponentContainDependencyRuleConfig {
//        let frameworks = Set(rules?["thirdpartyComponentContainsDependency"]["frameworks"].arrayObject as? [String] ?? [])
//        return ThirdpartyComponentContainDependencyRuleConfig(frameworks: frameworks)
//    }
//}
//
///// 检查第三方组件是否依赖其他组件。第三方组件尽可能避免引入其他改动，方便之后更新和复用
//enum ThirdpartyComponentContainDependencyRule: Rule {
//    static func check() async -> [any IIssue] {
//        let components = APP.shared.components
//        //
//        let thirdPartyFrameworks = APPAnalyze.shared.config.thirdpartyComponentContainsDependencyRule.frameworks
//        //
//        var issues: [ThirdpartComponentIssue] = []
//        for component in components {
//            let name = component.name
//            // 过滤第三方库
//            if !thirdPartyFrameworks.contains(name) {
//                continue
//            }
//            // 依赖数不为空
//            if !component.dependencies.isEmpty {
//                let dependencies = Array(component.dependencies)
//                let issue = ThirdpartComponentIssue(module: component.name, info: dependencies)
//                issues.append(issue)
//            }
//        }
//        return issues
//    }
//}

////
////  AntiPatternDependenciesRule.swift
////  APPAnalyze
////
////  Created by hexiao on 2021/11/9.
////
//
//import Foundation
//
//#warning("支持json配置")
//
//private let componentDepth: [String: Int] = ["pgBFoundationModule": 1, "pgUIKitModule": 2, "pgHermesModule": 2, "pgNavigationModule": 2, "pgImageModule": 2, "pgNetworkModule": 2, "pgDynamicFloorModule": 2, "pgCacheModule": 2, "pgBusinessComponentModule": 3, "JDBRouterModule": 3, "pgUniformRecommendModule": 3, "pgServiceModule": 3]
//
//struct AntiPatternDependenciesIssue: IIssue {
//    let name: String = "AntiPatternDependencies"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: [String]
//
//    let message: String = "组件层级反向依赖"
//
//    let type: IssueType = .antiPattern
//}
//
///// 检查组件层级之间的反向依赖。例如 Foundation和网络库都是基础组件，但是Foundation 组件不能依赖网络库
//enum AntiPatternDependenciesRule: Rule {
//    static func check() async -> [any IIssue] {
//        let components = APP.shared.components
//        //
//        var issues: [AntiPatternDependenciesIssue] = []
//        //
//        for component in components {
//            // 只检查基础组件
//            if !component.basic {
//                continue
//            }
//            //
//            var componentNames: [String] = []
//            if let depth = componentDepth[component.name] {
//                for dependencyName in component.dependencies {
//                    if let deep2 = componentDepth[dependencyName] {
//                        if deep2 > depth {
//                            componentNames.append(dependencyName)
//                        }
//                    }
//                }
//            }
//            //
//            if !componentNames.isEmpty {
//                let issue = AntiPatternDependenciesIssue(module: component.name, info: Array(componentNames))
//                issues.append(issue)
//            }
////            let issue = Issue(module: component.name, type: .ringDependence(Array(ringDependencies)))
////            issues.append(issue)
//            // 基础组件不使用Router以及实现 Router
//            // 基础组件不能依赖上层业务组件
//            // 公共组件不能依赖业务组件
//        }
//        return issues
//    }
//}

//
//  RingDependencyRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/16.
//

import Foundation

struct RingDependencyIssue: IIssue {
    let name: String = "RingDependency"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "组件间相互依赖"

    let type: IssueType = .module
}

/// 组件间不允许相互依赖
///
/// 俩个组件之间相互依赖
public enum RingDependencyRule: Rule {
    public static func check() async -> [any IIssue] {
        //
        var issues: [RingDependencyIssue] = []
        //
        let components = APP.shared.modules
        for component in components {
            var ringDependencies = component.dependencies.filter({ component.parentDependencies.contains($0) })
            if !ringDependencies.isEmpty {
                ringDependencies.insert(component.name)
                let issue = RingDependencyIssue(module: component.name, info: Array(ringDependencies))
                issues.append(issue)
            }
        }

        return issues
    }
}

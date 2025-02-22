//
//  DynamicFrameworkRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/9.
//

import Foundation

struct DynamicFrameworkIssue: IIssue {
    let name: String = "DynamicFramework"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "动态库"

    let type: IssueType = .performance
}

/// 扫描`动态库`。
/// 减少使用`动态库`提高冷启动速度
enum DynamicFrameworkRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [DynamicFrameworkIssue] = []
        // 扫描遍历所有二进制库
        for component in components {
            // 查找动态库
            let dynamicLibraries: [String] = component.libraries.filter { MachoTool.isDynamicFramework(path: $0.path) }.map { $0.name }
            //
            if !dynamicLibraries.isEmpty {
                let name = component.name
                let issue = DynamicFrameworkIssue(module: name, info: dynamicLibraries)
                issues.append(issue)
            }
        }

        return issues
    }
}

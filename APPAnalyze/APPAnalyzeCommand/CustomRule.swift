//
//  CustomRule.swift
//  APPAnalyzeCommand
//
//  Created by hexiao on 2023/11/14.
//

import Foundation
import APPAnalyzeCore

struct CustomIssue: IIssue {
    let name: String = "CustomIssue"

    let module: String

    let severity: Severity = .warning

    let info: String

    let message: String = "自定义错误"

    let type: IssueType = .size
}

/// 可以基于项目定制自定义规则
enum CustomRule: Rule {
    
    static func check() async -> [any IIssue] {
        var issues: [CustomIssue] = []
        let modules = APP.shared.modules
        for module in modules {
            let issue = CustomIssue(module: module.name, info: "123")
            issues.append(issue)
        }
        return issues
    }
    
}

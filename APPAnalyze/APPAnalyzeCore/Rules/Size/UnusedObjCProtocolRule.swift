//
//  UnusedObjCProtocolRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/4/13.
//

import Foundation

struct UnusedObjCProtocolIssue: IIssue {
    let name: String = "UnusedObjCProtocol"

    let module: String

    let severity: Severity = .warning

    let info: [String]

    let message: String = "未使用的ObjC协议"

    let type: IssueType = .size
}

/// 扫描未使用的`ObjC协议`。
/// 定义了协议未被使用
enum UnusedObjCProtocolRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var allUsedProtocols: Set<String> = []
        // 遍历统计所用被使用的协议
        for component in components {
            for library in component.libraries {
                // 类实现的协议
                for className in library.classlist {
                    if let objcClass = APP.shared.classlist[className] {
                        allUsedProtocols = allUsedProtocols.union(objcClass.allProtocols)
                    } else {
                        log("\(className)类不存在")
                    }
                }
                // Category实现的协议
                for objcCatgory in library.catlist {
                    allUsedProtocols = allUsedProtocols.union(objcCatgory.allProtocols)
                }
            }
        }
        //
        var issues: [UnusedObjCProtocolIssue] = []
        // 扫描遍历未使用的协议
        for component in components {
            var unusedProtocols: [String] = []
            for library in component.libraries {
                for protocolName in library.protolist {
                    if !allUsedProtocols.contains(protocolName) {
                        unusedProtocols.append(protocolName)
                    }
                }
                if !unusedProtocols.isEmpty {
                    let issue = UnusedObjCProtocolIssue(module: component.name, info: unusedProtocols)
                    issues.append(issue)
                }
            }
        }
        return issues
    }
}

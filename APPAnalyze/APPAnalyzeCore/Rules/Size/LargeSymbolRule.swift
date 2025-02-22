//
//  LargeSymbolRule.swift
//  APPAnalyzeCore
//
//  Created by hexiao on 2023/12/20.
//

import Foundation

struct LargeSymbolRuleItem: Encodable {
    let name: String
    let size: Int
}

struct LargeSymbolRuleIssue: IIssue {
    let name: String = "LargeSymbolRule"

    let module: String

    let severity: Severity = .warning

    let info: [LargeSymbolRuleItem]

    let message: String = "大符号Text"

    let type: IssueType = .size
}

struct LargeSymbolRuleConfig {
    let maxSize: Int
}

extension Configuration {
    var largeSymbolRule: LargeResourceRuleConfig {
        let maxSize = rules?["largeSymbol"]["maxSize"].int ?? 1024 * 10
        return LargeResourceRuleConfig(maxSize: maxSize)
    }
}

enum LargeSymbolRule: Rule {
    
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [LargeSymbolRuleIssue] = []
        // 读取配置
        let maxResourceSize = APPAnalyze.shared.config.largeSymbolRule.maxSize
        // 遍历扫描所有资源
        for component in components {
            var items: [LargeSymbolRuleItem] = []
            for library in component.libraries {
                for (_, symbol) in library.symbols {
                    if symbol.size >= maxResourceSize {
                        print(symbol.name)
                        let name = symbol.name.hasPrefix("_$") ? symbol.name.demangled : symbol.name
                        let item = LargeSymbolRuleItem(name: name, size: symbol.size)
                        items.append(item)
                    }
                }
            }
            //
            if !items.isEmpty {
                items = items.sorted(by: { $0.size > $1.size })
                let issue = LargeSymbolRuleIssue(module: component.name, info: items)
                issues.append(issue)
            }
        }
        
        return issues
    }
    
}

//
//  RuleManager.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/10.
//

import Foundation

/// 负责管理所有的规则和并行执行规则扫描。
///
/// 默认开启所有规则，除了组件依赖相关规则。
/// 可以调用`addRule`方法添加自定义的规则，调用`removeRule`方法移除规则
public class RuleManager {
    
    /// 扫描结束后的所有问题列表
    public private(set) var issues: [any IIssue] = []

    private var rules: [Rule.Type] = [LoadObjCClassRule.self, DynamicUseObjCClassRule.self, UnusedCategoryMethodsRule.self, DuplicateCategoryMethodsRule.self, UnusedClassRule.self, UnusedObjCMethodRule.self, DuplicateResourceRule.self, UnusedImagesetRule.self, UnusedResourceRule.self, LargeResourceRule.self, DynamicFrameworkRule.self, DuplicateObjCClassRule.self, ConflictCategoryMethodsRule.self, UnusedObjCProtocolRule.self, IncorrectObjCPropertyDefineRule.self, UnimplementedObjCProtocolMethodRule.self, BundleMutipleScaleImageRule.self, UnusedObjCPropertyRule.self, LargeSymbolRule.self]

    /// 添加自定义扫描规则
    /// - Parameter rule: 规则
    public func addRule(rule: Rule.Type) {
        if rules.contains(where: { $0 == rule }) {
            return
        }
        
        rules.append(rule)
    }
    
    /// 移除扫描规则
    /// - Parameter rule: 规则
    public func removeRule(rule: Rule.Type) {
        rules.removeAll(where: { $0 == rule })
    }

    func check() async {
        let allIssues = await withTaskGroup(of: [any IIssue].self) { taskGroup in
            for rule in rules {
                taskGroup.addTask {
                    let date = Date()
                    print("\(rule)：开始检查")
                    let issues = await rule.check()
                    print("\(rule)：结束检查-耗时\(-Int(date.timeIntervalSinceNow))s")
                    return issues
                }
            }
            //
            var allIssues: [any IIssue] = []
            for await result in taskGroup {
                allIssues.append(contentsOf: result)
            }

            return allIssues
        }
        issues = allIssues
    }
}

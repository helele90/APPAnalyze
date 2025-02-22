//
//  Rule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

/// 规则协议
public protocol Rule {
    
    /// 检查
    /// - Returns: 返回`Issue`数组
    static func check() async -> [any IIssue]
    
}

// 静态检查
// 1.Swift - 未使用类方法
// 2.Swift - 未使用属性或符号
// 3.基础组件类使用率 - 如果使用率太低考虑移除
// 4.调用的 objc 方法不存在 - 可以考虑
// 5.bundle未使用 - 意义不大？
// 6.动态库如何识别相互依赖

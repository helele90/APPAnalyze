//
//  APPAnalyze.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/14.
//

import Foundation

/// APPAnalyze 主分析器
public class APPAnalyze {
    
    /// 共享单例
    public static let shared = APPAnalyze()
    
    /// 解析器
    ///
    /// - Warning: 默认为 nil，需要配置
    public var parser: Parser!
    
    /// 扫描配置
    public let config = Configuration()
    
    /// 规则管理器
    public let ruleManager = RuleManager()
    
    /// 报告生成器
    public let reporterManager: ReporterManager = ReporterManager()
    
    /// 开始执行
    public func run() async {
        config.check()
        // 解析工程或IPA为模块
        let modules = await parser.parse()
        // 解析模块 macho 和资源
        await ModuleParser.parse(modules: modules)
        // 规则扫描
        await ruleManager.check()
        // 生成数据
        await reporterManager.print()
    }
}

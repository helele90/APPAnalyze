//
//  MainCommand.swift
//  APPAnalyzeCommand
//
//  Created by hexiao on 2022/4/18.
//

import APPAnalyzeCore
import ArgumentParser
import Foundation

@main
struct MainCommand: AsyncParsableCommand {
//    #if RELEASE
        @Option(help: "当前版本1.3.1")
        var version: String?
    
#if DEBUG

    var output: String = "/Users/hexiao/Desktop/ipas/pinduoduo3"

    var config: String = "/Users/hexiao/Desktop/ipas/config.json"

    var ipa: String? = "/Users/hexiao/Desktop/ipas/pinduoduo/pinduoduo.app"

    var modules: String?
    
    var arch: String = "arm64"

#endif
    
#if RELEASE

        @Option(help: "输出文件目录")
        var output: String

        @Option(help: "配置JSON文件地址")
        var config: String?

        @Option(help: "ipa.app文件地址")
        var ipa: String?

        @Option(help: "工程文件目录")
        var modules: String?
    
    @Option(help: "指令集架构：arm64、x86_64")
    var arch: String = "arm64"

#endif
    
//    /Users/hexiao/Desktop/ipas/1.2.0/APPAnalyzeCommand --ipa /Users/hexiao/Desktop/ipas/pinduoduo/pinduoduo.app --config /Users/hexiao/Desktop/ipas/config.json --output /Users/hexiao/Desktop/ipas/pinduoduo/APPAnalyze

    mutating func run() async throws {
        let date = Date()
        #if DEBUG
        CommandLine.arguments = ["/Users/hexiao/ibiu_project/test/Example/TestOC", "-ipa", "/Users/hexiao/Desktop/ipas/pinduoduo/pinduoduo.app", "-config", "/Users/hexiao/Desktop/ipas/config.json", "--output", "/Users/hexiao/Desktop/ipas/pinduoduo2"]
        #endif
        //
        log("执行参数：\(CommandLine.arguments)")
        //
        let appAnalyze = APPAnalyze.shared
        // 执行参数配置
        let analyzeConfig = appAnalyze.config
        analyzeConfig.archType = ArchType(rawValue: arch) ?? .arm64
        var currentDirectoryPath = CommandLine.arguments[0]
        var url = URL(string: currentDirectoryPath)!
        url.deleteLastPathComponent()
        currentDirectoryPath = url.absoluteString
        analyzeConfig.currentDirectoryPath = currentDirectoryPath
        analyzeConfig.configPath = config
        analyzeConfig.reportOutputPath = output
        // 解析器和规则配置
        if let modules = self.modules {
            appAnalyze.parser = ModuleFileParser(path: modules)
            //
            let ruleManager = appAnalyze.ruleManager
            ruleManager.addRule(rule: DuplicateResourceInBundleRule.self)
            ruleManager.addRule(rule: RingDependencyRule.self)
            ruleManager.addRule(rule: UnusedModuleRule.self)
            ruleManager.addRule(rule: GlobalUnusedModuleRule.self)
        } else if let ipa = self.ipa {
            appAnalyze.parser = IPAParser(appPath: ipa)
        } else {
            fatalError("参数错误")
        }
        //
        await appAnalyze.run()
        //
        log("结束执行")
        print("总耗时\(-Int(date.timeIntervalSinceNow))s")
    }
}

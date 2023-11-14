//
//  MainCommand.swift
//  APPAnalyzeCommand
//
//  Created by hexiao on 2023/4/18.
//

import APPAnalyzeCore
import ArgumentParser
import Foundation

@main
struct MainCommand: AsyncParsableCommand {
//    #if RELEASE
        @Option(help: "当前版本1.2.0")
        var version: String?
    
#if DEBUG

    var output: String = "/Users/hexiao/Desktop/ipas/pinduoduo3"

    var config: String = "/Users/hexiao/Desktop/ipas/config.json"

    var ipa: String? = "/Users/hexiao/Desktop/ipas/pinduoduo/pinduoduo.app"

    var modules: String?

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

#endif

    mutating func run() async throws {
        let date = Date()
        #if DEBUG
        CommandLine.arguments = ["/Users/hexiao/ibiu_project/JDLTAppModule/Example/TestOC"]
        #endif
        //
        log("执行参数：\(CommandLine.arguments)")
        //
        let appAnalyze = APPAnalyze.shared
        //
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
        appAnalyze.reporterManager.outputPath = output
        //
        await appAnalyze.run()
        //
        log("结束执行")
        print("总耗时\(-Int(date.timeIntervalSinceNow))s")
    }
}

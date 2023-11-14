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

    var config: String? = "/Users/hexiao/Desktop/ipas/config.json"

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
        var arguments = ["/Users/hexiao/ibiu_project/JDLTAppModule/Example/TestOC"]
        if let ipa = ipa {
            arguments.append("-ipa")
            arguments.append(ipa)
        }
        if let config = config {
            arguments.append("-config")
            arguments.append(config)
        }
        arguments.append("-output")
        arguments.append(output)
        CommandLine.arguments = arguments
        #endif
        //
        log("执行参数：\(CommandLine.arguments)")
        //
        let appAnalyze = APPAnalyze.shared
        //
        if let modules = self.modules {
            appAnalyze.parser = ModuleFileParser(path: modules)
            // 添加组件化工程检查
            let ruleManager = appAnalyze.ruleManager
            ruleManager.addRule(rule: DuplicateResourceInBundleRule.self)
            ruleManager.addRule(rule: RingDependencyRule.self)
            ruleManager.addRule(rule: UnusedModuleRule.self)
            ruleManager.addRule(rule: GlobalUnusedModuleRule.self)
        } else if let ipa = self.ipa { // IPA 模式
            appAnalyze.parser = IPAParser(appPath: ipa)
        } else {
            fatalError("参数错误")
        }
#if DEBUG
//        appAnalyze.parser = CustomParser()
        appAnalyze.ruleManager.addRule(rule: CustomRule.self)
        appAnalyze.reporterManager.addReporter(reporter: CustomReporter.self)
#endif
        //
        appAnalyze.reporterManager.outputPath = output
        //
        await appAnalyze.run()
        //
        log("结束执行")
        print("总耗时\(-Int(date.timeIntervalSinceNow))s")
    }
}

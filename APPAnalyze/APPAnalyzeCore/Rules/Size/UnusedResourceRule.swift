//
//  UnusedResourceRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/9.
//

import Foundation

struct UnusedResourceRuleIssue: IIssue {
    let name: String = "UnusedResource"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedFile]

    let message: String = "未使用的资源"

    let type: IssueType = .size
}

struct UnusedResourceRuleConfig {
    let excludeNameRegex: [String]
}

extension Configuration {
    var unusedResourceRule: UnusedResourceRuleConfig {
        let excludeNameRegex = rules?["unusedResource"]["excludeNameRegex"].arrayObject as? [String] ?? []
        return UnusedResourceRuleConfig(excludeNameRegex: excludeNameRegex)
    }
}

/// 检查未使用的资源
enum UnusedResourceRule: Rule {
    private static func getUsedString(text: String) -> String {
        var fileName = text.fileName
        // 移除scale后缀
        if fileName.hasSuffix("@2x") || fileName.hasSuffix("@3x") {
            let endIndex = fileName.index(fileName.endIndex, offsetBy: -3)
            fileName = String(fileName[fileName.startIndex ..< endIndex])
        }
        // 移除 bundle 前缀
        if let range = fileName.range(of: ".bundle/") {
            let startIndex = range.upperBound
            fileName = String(fileName[startIndex ..< fileName.endIndex])
        }
        return fileName
    }

    private static func getFileName(text: String) -> String {
        var fileName = text.fileName
        // 移除scale后缀
        if fileName.hasSuffix("@2x") || fileName.hasSuffix("@3x") {
            let endIndex = fileName.index(fileName.endIndex, offsetBy: -3)
            fileName = String(fileName[fileName.startIndex ..< endIndex])
        }
        return fileName
    }

    static func check() async -> [any IIssue] {
        // 读取配置
        let config = APPAnalyze.shared.config.unusedImagesetRule
        let excludeNameRegex = config.excludeNameRegex
        //
        let components = APP.shared.modules
        var issues: [UnusedResourceRuleIssue] = []
        var allUsedStrings: Set<String> = []
        // 遍历所有组件
        for component in components {
            // 遍历统计所有使用的字符串
            var usedStrings: Set<String> = []
            for library in component.libraries {
                for usedString in library.usedStrings {
                    usedStrings.insert(getUsedString(text: usedString))
                }
            }
            allUsedStrings = allUsedStrings.union(usedStrings)
        }

        // 基础组件检查
        for component in components {
            let name = component.name
            let bundles = component.resource.bundles
            //
            var unusedResources: [UnusedFile] = []
            for bundle in bundles {
                let files = bundle.files
                for file in files {
                    let fileName = file.name
                    // Localizable暂不处理
                    if fileName.hasSuffix(".strings") {
                        continue
                    }
                    //
                    if fileName.hasPrefix("AppIcon") {
                        continue
                    }
                    // Assets.car暂不处理
                    if fileName == "Assets.car" || fileName == "LaunchScreen.storyboardc" || fileName == "Main.storyboardc" || fileName == "Root.plist" || fileName == "Info.plist" {
                        continue
                    }
                    // 正则表达式过滤
                    for regex in excludeNameRegex {
                        let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                        if RE?.firstMatch(in: fileName, range: NSRange(location: 0, length: fileName.count)) != nil {
                            continue
                        }
                    }
                    // 移除@2x/3x后缀名，因为一般都不会直接写死
                    let shortFileName = getFileName(text: fileName)
                    //
                    if !allUsedStrings.contains(shortFileName) {
                        let unusedResource = UnusedFile(name: fileName, size: file.size, bundle: bundle.name)
                        unusedResources.append(unusedResource)
                    }
                }
            }
            //
            unusedResources = unusedResources.sorted(by: { $0.size > $1.size })
            if !unusedResources.isEmpty {
                let issue = UnusedResourceRuleIssue(module: name, info: unusedResources)
                issues.append(issue)
            }
        }

        return issues
    }
}

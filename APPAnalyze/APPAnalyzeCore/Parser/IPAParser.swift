//
//  IPAParser.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/4/10.
//

import Foundation

#warning("暂不支持plugins/watch.app")

/// IPA 解析器
///
/// 将 `IPA`解析为`Macho`和`资源`的数据结构，以`Framework`为粒度
/// - Warning: 暂不支持支持 `plugins`/`watch.app`
public class IPAParser: Parser {
    
    private let appPath: String
    
    /// 初始化 IPAParser
    /// - Parameter appPath: .app的文件路径
    /// - Warning: 不能直接使用`IPA`，需要先解压
    public init(appPath: String) {
        self.appPath = appPath
    }
    
    public func parse() async -> [ModuleInfo] {
        var target = URL(string: appPath)!.lastPathComponent
        if target.hasSuffix(".app") {
            let endIndex = target.index(target.endIndex, offsetBy: -4)
            target = String(target[target.startIndex..<endIndex])
        }
        //
        var modules: [ModuleInfo] = []
        // 动态库
        let dynamicComponents = Self.parseDynamicFrameworks(appPath: appPath, target: target)
        // 主库
        var mainComponent = Self.parseMainFramework(appPath: appPath, target: target)
        // 设置主库依赖
        mainComponent.dependencies = Set(dynamicComponents.map { $0.name })
        modules.append(mainComponent)
        // 设置动态库依赖
        dynamicComponents.forEach { component in
            var dynamicComponent = component
            var dynamicDependencies = dynamicComponents.filter { $0.name != component.name }.map { $0.name }
            dynamicDependencies.append(mainComponent.name)
            dynamicComponent.dependencies = Set(dynamicDependencies)
            modules.append(dynamicComponent)
        }
        return modules
    }

    private static func parseMainFramework(appPath: String, target: String) -> ModuleInfo {
        var resourcePaths: Set<String> = []
        //
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: appPath)) ?? []
        for content in contents {
            // 过滤部分文件夹
            if content == "Frameworks" || content == "_CodeSignature" || content == "SC_Info" || content == "PlugIns" {
                continue
            }
            // 过滤 macho
            if content == target {
                continue
            }
            //
            let resourcePath = "\(appPath)/\(content)"
            resourcePaths.insert(resourcePath)
        }
        //
        let libraryPath = "\(appPath)/\(target)"
        let module = ModuleInfo(name: target, version: nil, frameworks: [], libraries: [libraryPath], resources: resourcePaths, dependencies: [], mainModule: true)
        return module
    }

    private static func parseDynamicFrameworks(appPath: String, target: String) -> [ModuleInfo] {
        var components: [ModuleInfo] = []
        //
        let frameworksPath = "\(appPath)/Frameworks"
        let frameworks = (try? FileManager.default.contentsOfDirectory(atPath: frameworksPath)) ?? []
        for framework in frameworks {
            // 只处理framework
            if !framework.hasSuffix(".framework") {
                continue
            }
            //
            let directory = "\(frameworksPath)/\(framework)"
            //
            let index = framework.index(framework.endIndex, offsetBy: -10)
            let frameworkName = String(framework[..<index])
            //
            var resourcePaths: Set<String> = []
            //
            let frameworkContents = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
            for frameworkContent in frameworkContents {
                if frameworkContent == frameworkName {
                    continue
                }

                if frameworkContent == "_CodeSignature" || frameworkContent == "SC_Info" {
                    continue
                }
                //
                let path = "\(directory)/\(frameworkContent)"
                resourcePaths.insert(path)
            }
            //
            let component = ModuleInfo(name: frameworkName, version: nil, frameworks: [directory], libraries: [], resources: resourcePaths, dependencies: [], mainModule: false)
            //
            components.append(component)
        }

        return components
    }
}

//
//  ModuleParser.swift
//  APPAnalyzeCore
//
//  Created by hexiao on 2023/10/9.
//

import Foundation

#warning("解析 framework 里的资源")

enum ModuleParser {
    static func parse(modules: [ModuleInfo]) async {
        let frameworks = await withTaskGroup(of: Module.self) { taskGroup in
            // 解析模块
            for module in modules {
                taskGroup.addTask {
                    let framework = await Self.parse(module: module)
                    return framework
                }
            }
            // 解析系统库
            let systemFrameworksPath = APPAnalyze.shared.config.customConfig?["systemFrameworkPaths"].arrayObject as? [String] ?? []
            for path in systemFrameworksPath {
                taskGroup.addTask {
                    if let frameworkName = URL(string: path)?.lastPathComponent {
                        print("\(frameworkName):解析系统库")
                    }
                    let framework = await parseSystemFramework(path: path)
                    return framework
                }
            }
            //
            var frameworks: [Module] = []
            for await result in taskGroup {
                frameworks.append(result)
            }

            return frameworks
        }
        // 计算每个模块的所有依赖
        for component in frameworks {
            var allDependencies: Set<String> = []
            for name in component.dependencies {
                allDependencies.insert(name)
                //
                let component = frameworks.first(where: { $0.name == name })
                component?.dependencies.forEach { name2 in
                    allDependencies.insert(name2)
                }
            }
            component.allDependencies = allDependencies
            //
            var dependencies = component.dependencies
            dependencies.remove(component.name)
            component.dependencies = dependencies
        }
        //
        for framework in frameworks {
            // 查找自己被哪些模块依赖
            let moduleName = framework.name
            let parentDependencies = Set(frameworks.filter({ $0.dependencies.contains(moduleName) }).map({ $0.name }))
//            parentDependencies.remove(moduleName)
            framework.parentDependencies = parentDependencies
            //
            APP.shared.insertComponent(component: framework)
        }
        //
        APP.shared.calculateAllSuperClassAndProtocol()
        //
        APPAnalyze.shared.reporterManager.generateReport(data: modules.data, fileName: "modules.json")
    }

    private static func parseSystemFramework(path: String) async -> Module {
        let objcData = await MachoTool.getObjCData(path: path)
        let framework = Module()
        framework.systemLibrary = true
        //
        let library = MachO(name: "", classlist: [], catlist: objcData.catlist, protolist: [], classrefs: [], superrefs: [], selrefs: [], ivarTypeRefs: [], usedStrings: [], path: "", objcIvarRefs: [], arch: .arm64, classlist2: objcData.classlist, protolist2: objcData.protolist, symbols: [:], usedSymbols: [])
        framework.libraries = [library]
        return framework
    }

    private static func parse(module: ModuleInfo) async -> Module {
        let component = Module()
        component.name = module.name
        component.version = module.version
        component.mainModule = module.mainModule
        //
        let resource = await Self.parseResource(module: module)
        component.resource = resource
        //
        let archType = APPAnalyze.shared.config.archType
        //
        let libraries = await withTaskGroup(of: MachO.self) { taskGroup in
            // 解析 framework 的 macho
            for frameworkPath in module.frameworks {
                let frameworkName = URL(string: frameworkPath)!.lastPathComponent.components(separatedBy: ".").first!
                let machoPath = "\(frameworkPath)/\(frameworkName)"
                taskGroup.addTask {
                    let library = await MachoTool.getMachoInfo(path: machoPath, dynamic: true, arch: archType)
                    return library
                }
            }
            // 解析 library 的 macho
            for libraryPath in module.libraries {
                taskGroup.addTask {
                    let library = await MachoTool.getMachoInfo(path: libraryPath, dynamic: false, arch: archType)
                    return library
                }
            }
            //
            var libraries: [MachO] = []
            for await result in taskGroup {
                libraries.append(result)
            }
            return libraries
        }
        //
        component.libraries = libraries
        component.dependencies = module.dependencies
        return component
    }

    private static func parseResource(module: ModuleInfo) async -> ComponentResource {
        print("\(module.name):解析资源")
        var bundles: [ResourceBundle] = []
        var files: [File] = []
        var allDataSets: Set<ResourceDataSet> = []
        var allImageSets: Set<ResourceImageSet> = []
        //
        var insertedFiles: Set<String> = []
        //
        func insertFile(contentPath: String) {
            if insertedFiles.contains(contentPath) {
                return
            }
            //
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: contentPath, isDirectory: &isDirectory)
            // 文件夹
            if isDirectory.boolValue {
                // 过滤部分文件夹
                if contentPath.hasSuffix("Frameworks") || contentPath.hasSuffix("_CodeSignature") || contentPath.hasSuffix("PlugIns") || contentPath.hasSuffix("SC_Info") {
                    return
                }
                // storyboardc
                if contentPath.hasSuffix(".storyboardc") {
                    let size = FileTool.getDirectorySize(path: contentPath)
                    let name = contentPath.split(separator: "/").last!
                    let file = File(name: String(name), path: contentPath, size: size)
                    files.append(file)
                    //
                    insertedFiles.insert(contentPath)
                    return
                }
                //
                if contentPath.hasSuffix(".bundle") {
                    if let bundle = BundleTool.parseBundle(path: contentPath) {
                        bundles.append(bundle)
                    } else {
                        assertionFailure()
                    }
                    //
                    insertedFiles.insert(contentPath)
                    return
                }
                //
                if contentPath.hasSuffix(".xcassets") {
                    let (imageSets, dataSets) = XCAssetsTool.parseAssets(path: contentPath)
                    allDataSets.formUnion(dataSets)
                    allImageSets.formUnion(imageSets)
                    //
                    insertedFiles.insert(contentPath)
                    return
                }
                //
                insertedFiles.insert(contentPath)
                //
                let subpaths = FileManager.default.subpaths(atPath: contentPath) ?? []
                for subpath in subpaths {
                    let subpath2 = "\(contentPath)/\(subpath)"
                    insertFile(contentPath: subpath2)
                    //
                    insertedFiles.insert(subpath2)
                }
            } else {
                insertedFiles.insert(contentPath)
                // 解析主assets.car
                if contentPath.hasSuffix("Assets.car") {
                    let (imageSets, dataSets) = AssetsCarTool.parseAssets(path: contentPath)
                    allDataSets.formUnion(dataSets)
                    allImageSets.formUnion(imageSets)
                    return
                }
                //
                let fileSize = FileTool.getFileSize(path: contentPath)
                if fileSize > 0 {
                    let name = contentPath.split(separator: "/").last!
                    let file = File(name: String(name), path: contentPath, size: Int(fileSize))
                    files.append(file)
                }
            }
        }
        //
        for contentPath in module.resources {
            insertFile(contentPath: contentPath)
        }
        //
        let mainBundle = ResourceBundle(name: MainBundleName, files: files, imageSets: allImageSets, datasets: allDataSets)
        bundles.append(mainBundle)
        return ComponentResource(bundles: bundles, size: 0)
    }
}

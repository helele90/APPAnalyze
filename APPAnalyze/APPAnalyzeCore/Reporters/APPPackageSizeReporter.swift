//
//  APPPackageSizeReporter.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/25.
//

import Foundation

struct AppPackageSize: Encodable {
    let allSize: Int
    let binarySize: Int
    let resourceSize: Int
    let components: [ModulePackageSize]
}

struct ModulePackageSize: Encodable {
    let name: String
    let version: String?
    let size: Int
    let libraries: [MobuleLibrarySize]
    let resource: ModuleResourceSize
}

struct MobuleLibrarySize: Encodable {
    let name: String
    let size: Int
    let files: [LibraryFileSize]
    let frameworks: [IbiuComponentFrameworkSize]

    enum CodingKeys: String, CodingKey {
        case name
        case frameworks
        case size
        case files
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(size, forKey: .size)
        if !frameworks.isEmpty {
            try container.encode(frameworks, forKey: .frameworks)
        }
        if !files.isEmpty {
            try container.encode(files, forKey: .files)
        }
    }
}

struct IbiuComponentFrameworkSize: Encodable {
    let name: String
    let size: Int
}

struct ModuleResourceSize: Encodable {
    let bundles: [IbiuComponentSizeResourceBundle]
    let size: Int

    enum CodingKeys: String, CodingKey {
        case bundles
        case size
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        if !bundles.isEmpty {
            try container.encode(bundles, forKey: .bundles)
        }
    }
}

struct IbiuComponentSizeResourceBundle: Encodable {
    let name: String
    let size: Int
    let files: [IbiuComponentSizeResourceFile]
    let assets: [IbiuComponentSizeResourceAsset]

    enum CodingKeys: String, CodingKey {
        case name
        case files
        case imagesets
        case size
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(size, forKey: .size)
        if !files.isEmpty {
            try container.encode(files, forKey: .files)
        }
        if !assets.isEmpty {
            try container.encode(assets, forKey: .imagesets)
        }
    }
}

struct IbiuComponentSizeResourceFile: Encodable {
    let name: String
    let size: Int
}

struct IbiuComponentSizeResourceAsset: Encodable {
    let name: String
    let size: Int
}

/// 包体积数据生成
enum APPPackageSizeReporter: Reporter {
    static func generateReport() async {
        let components: [Module] = APP.shared.modules
        //
        var componentSizeInfos: [ModulePackageSize] = []
        var allBinarySize = 0
        var allResourceSize = 0
        //
        for component in components {
            // 统计二进制大小
            var libraries: [MobuleLibrarySize] = []
            var librarySize = 0
            for machoModule in component.libraries {
                let frameworkSize = machoModule.frameworkSize
                let binarySize = MobuleLibrarySize(name: machoModule.name, size: frameworkSize.totalSize, files: frameworkSize.files, frameworks: [])
                libraries.append(binarySize)
                librarySize += frameworkSize.totalSize
            }
            //
            allBinarySize += librarySize
            // 统计资源大小
            var resourceSize = 0
            let resource = component.resource!
            var bundles: [IbiuComponentSizeResourceBundle] = []
            for bundle in resource.bundles {
                var bundleSize = 0
                // 统计文件
                var files: [IbiuComponentSizeResourceFile] = []
                for file in bundle.files {
                    // 过滤 imageSet/dataset
                    if !file.path.contains("imageset"), !file.path.contains("dataset") {
                        let fileSize = IbiuComponentSizeResourceFile(name: file.name, size: file.size)
                        files.append(fileSize)
                        // Assets.car尺寸不统计
                        if file.name != "Assets.car" {
                            bundleSize += fileSize.size
                        }
                    }
                }
                // 统计 imageSet
                var assets: [IbiuComponentSizeResourceAsset] = []
                for imageSet in bundle.imageSets {
                    let size = imageSet.size
                    let imageSetSize = IbiuComponentSizeResourceAsset(name: imageSet.name, size: size)
                    assets.append(imageSetSize)
                    bundleSize += size
                }
                // 统计 dataset
                for dataset in bundle.datasets {
                    let size = dataset.size
                    let datasetSize = IbiuComponentSizeResourceAsset(name: dataset.name, size: size)
                    assets.append(datasetSize)
                    bundleSize += size
                }
                //
                let bundle = IbiuComponentSizeResourceBundle(name: bundle.name, size: bundleSize, files: files, assets: assets)
                bundles.append(bundle)
                //
                resourceSize += bundleSize
            }
            let resourceSizeInfo = ModuleResourceSize(bundles: bundles, size: resourceSize)
            //
            let allSize = librarySize + resourceSize
            let name = component.name
            let version = component.version
            let info = ModulePackageSize(name: name, version: version, size: allSize, libraries: libraries, resource: resourceSizeInfo)
            componentSizeInfos.append(info)
            //
            allResourceSize += resourceSize
        }
        // 按大小排序
        componentSizeInfos.sort(by: { $0.size > $1.size })
        //
        let allSize = allBinarySize + allResourceSize
        //
        let size = AppPackageSize(allSize: allSize, binarySize: allBinarySize, resourceSize: allResourceSize, components: componentSizeInfos)
        // 保存文件
        APPAnalyze.shared.reporterManager.generateReport(data: size.data, fileName: "package_size.json")
        //
        let encoder = JSONEncoder()
        let data = try! encoder.encode(size)
        let string = String(data: data, encoding: .utf8)!
        let script = "<script>var appSizeData = \(string);</script>"
        //
        let html = """
        <!doctype html><html><head><meta charset="utf-8"/><meta name="viewport"content="width=device-width, initial-scale=1.0"/><style type="text/css">body{font-family:Arial,Helvetica,sans-serif;font-size:0.9rem}table{border:1px solid gray;border-collapse:collapse;-moz-box-shadow:3px 3px 4px#AAA;-webkit-box-shadow:3px 3px 4px#AAA;box-shadow:3px 3px 4px#AAA;vertical-align:top;height:64px}td,th{border:1px solid#D3D3D3;padding:5px 10px 5px 10px;text-align:center}th{border-bottom:1px solid black;background-color:#FAFAFA}</style><title>包体积</title>\(script)<script>function renderAppInfo(data){const version=data.version;const allSize=formatSize(data.allSize);const binarySize=formatSize(data.binarySize);const resourceSize=formatSize(data.resourceSize);document.getElementById('allSize').innerHTML=allSize;document.getElementById('binarySize').innerHTML=binarySize;document.getElementById('resourceSize').innerHTML=resourceSize}function renderModulesInfo(data){var trs='';for(var i=0;i<data.components.length;i++){const component=data.components[i];const name=component.name;const version=component.version;const resourceSize=formatSize(component.resource.size);const allSize=formatSize(component.size);const binarySize=formatSize(component.size-component.resource.size);const sizePercent=(component.size/data.allSize*100).toFixed(1);const link=`./module_size.html?framework=${name}`;const tr=`<tr><td>${i+1}</td><td><a target="_blank"href="${link}">${name}</a></td><td>${binarySize}</td><td>${resourceSize}</td><td>${allSize}</td><td>${sizePercent}%</td></tr>`;trs+=tr}document.getElementById('module_tbody').innerHTML=trs}function formatSize(size){if(size==0){return''}let a=size;if(a<1000){return`${a}B`}a=parseInt(a/1000);if(a<1000){return`${a}KB`}a=a/1000;return`${a.toFixed(1)}MB`}function onLoad(){const data=appSizeData;renderAppInfo(data);renderModulesInfo(data)}</script></head><body onload="onLoad()"><h1>包体积</h1><table><thead><tr><th style="width: 60pt;"><b>二进制大小</b></th><th style="width: 60pt;"><b>资源大小</b></th><th style="width: 60pt;"><b>总大小</b></th></tr></thead><tbody><tr><td id="binarySize"style="text-align: center;"></td><td id="resourceSize"style="text-align: center;"></td><td id="allSize"style="text-align: center;"></td></tr></tbody></table><h2>模块大小</h2><table><thead><tr><th style="width: 50pt;"><b>序号</b></th><th style="width: 120pt;"><b>模块名</b></th><th style="width: 60pt;"><b>二进制大小</b></th><th style="width: 60pt;"><b>资源大小</b></th><th style="width: 60pt;"><b>总大小</b></th><th style="width: 60pt;"><b>总大小占比</b></th></tr></thead><tbody id="module_tbody"></tbody></table><br/></body></html>
        """
        APPAnalyze.shared.reporterManager.generateReport(text: html, fileName: "app_size.html")
        //
        let html2 = """
        <!doctype html><html><head><meta charset="utf-8"/><meta name="viewport"content="width=device-width, initial-scale=1.0"/><style type="text/css">body{font-family:Arial,Helvetica,sans-serif;font-size:0.9rem}table{border:1px solid gray;border-collapse:collapse;-moz-box-shadow:3px 3px 4px#AAA;-webkit-box-shadow:3px 3px 4px#AAA;box-shadow:3px 3px 4px#AAA;vertical-align:top;height:64px}a{text-decoration:none}td,th{border:1px solid#D3D3D3;padding:5px 10px 5px 10px;text-align:center}th{border-bottom:1px solid black;background-color:#FAFAFA}</style><title>模块体积</title>\(script)<script>function getPackageSizeInfo(module){const data=appSizeData;for(let i=0;i<data.components.length;i++){const component=data.components[i];const name=component.name;if(name==module){renderAppInfo(component);renderModulesInfo(component);renderModulesInfo2(component);break}}}function renderAppInfo(data){const version=data.version;const allSize=formatSize(data.size);const binarySize=formatSize(data.size-data.resource.size);const resourceSize=formatSize(data.resource.size);document.getElementById('allSize').innerHTML=allSize;document.getElementById('binarySize').innerHTML=binarySize;document.getElementById('resourceSize').innerHTML=resourceSize}function renderModulesInfo(data){let items=new Array();for(let i=0;i<data.libraries.length;i++){const library=data.libraries[i];const files=library.files;if(files&&files.length>0){for(let j=0;j<files.length;j++){const file=files[j];const name=file.name;const size=file.size;const libraryName=library.name;items.push({name,size,library:libraryName})}}else{items.push({name:library.name,size:library.size,library:''})}}items.sort(function(a,b){return b.size-a.size});let trs='';for(let i=0;i<items.length;i++){const item=items[i];const tr=`<tr><td>${i+1}</td><td>${item.name}</td><td>${formatSize(item.size)}</td><td>${item.library}</td></tr>`;trs+=tr}document.getElementById('module_tbody').innerHTML=trs}function renderModulesInfo2(data){let items=new Array();const bundles=data.resource.bundles;if(!bundles){document.getElementById('module_tbody2').innerHTML='';return}for(let i=0;i<data.resource.bundles.length;i++){const bundle=data.resource.bundles[i];if(bundle.files){const files=bundle.files;for(let j=0;j<files.length;j++){const file=files[j];const name=file.name;const size=file.size;items.push({name,size,bundle:bundle.name})}}if(bundle.imagesets){const imagesets=bundle.imagesets;for(let j=0;j<imagesets.length;j++){const imageset=imagesets[j];const name=`${imageset.name}.imageset`;const size=imageset.size;items.push({name,size,bundle:bundle.name})}}}items.sort(function(a,b){return b.size-a.size});let trs='';for(let i=0;i<items.length;i++){const item=items[i];const tr=`<tr><td>${i+1}</td><td>${item.name}</td><td>${formatSize(item.size)}</td><td>${item.bundle}</td></tr>`;trs+=tr}document.getElementById('module_tbody2').innerHTML=trs}function formatSize(size){if(size==0){return''}let a=size;if(a<1000){return`${a}B`}a=parseInt(a/1000);if(a<1000){return`${a}KB`}a=a/1000;return`${a.toFixed(1)}MB`}function onLoad(){const framework=getQueryVariable('framework');getPackageSizeInfo(framework);document.getElementById('framework').innerHTML=framework;}function getQueryVariable(variable){var query=window.location.search.substring(1);var vars=query.split("&");for(var i=0;i<vars.length;i++){var pair=vars[i].split("=");if(pair[0]==variable){return pair[1]}}return(false)}</script></head><body onload="onLoad()"><h2>总大小</h2><table><thead><tr><th style="width: 60pt;"><b>模块</b></th><th style="width: 60pt;"><b>二进制大小</b></th><th style="width: 60pt;"><b>资源大小</b></th><th style="width: 60pt;"><b>总大小</b></th></tr></thead><tbody><tr><td id="framework"style="text-align: center;"></td><td id="binarySize"style="text-align: center;"></td><td id="resourceSize"style="text-align: center;"></td><td id="allSize"style="text-align: center;"></td></tr></tbody></table><div style="display:flex;"><div><h2>二进制大小</h2><table><thead><tr><th style="width: 50pt;"><b>序号</b></th><th style="width: 120pt;"><b>文件名</b></th><th style="width: 60pt;"><b>大小</b></th><th style="width: 120pt;"><b>库名</b></th></tr></thead><tbody id="module_tbody"></tbody></table></div><div style="margin-left: 100pt;"><h2>资源大小</h2><table><thead><tr><th style="width: 60pt;"><b>序号</b></th><th style="width: 120pt;"><b>文件名</b></th><th style="width: 60pt;"><b>大小</b></th><th style="width: 120pt;"><b>Bundle</b></th></tr></thead><tbody id="module_tbody2"></tbody></table></div></div></body></html>
        """
        APPAnalyze.shared.reporterManager.generateReport(text: html2, fileName: "module_size.html")
    }
}

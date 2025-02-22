//
//  BundleTool.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/2.
//

import Foundation

/// 字符串`Main`
///
/// Main Bundle 名字
public let MainBundleName = "Main"

struct BundleTool {
    /// 解析Bundle文件
    /// - Parameters:
    ///   - path: bundle 文件夹
    /// - Returns: Bundle 资源
    static func parseBundle(path: String) -> ResourceBundle? {
        guard var bundleName = path.components(separatedBy: "/").last, bundleName.hasSuffix(".bundle") else {
            assertionFailure()
            log("Bundle目录错误:\(path)")
            return nil
        }
        let endIndex = bundleName.index(bundleName.endIndex, offsetBy: -7)
        bundleName = String(bundleName[bundleName.startIndex ..< endIndex])
        //
        let subpaths = FileManager.default.subpaths(atPath: path) ?? []
        // 遍历所有文件
        var files: [File] = []
        var imageSets: Set<ResourceImageSet> = []
        var dataSets: Set<ResourceDataSet> = []
        for content in subpaths {
            var isDirectory: ObjCBool = false
            let contentPath = "\(path)/\(content)"
            FileManager.default.fileExists(atPath: contentPath, isDirectory: &isDirectory)
            // 过滤文件夹
            if isDirectory.boolValue {
                continue
            }
            // 解析Assets
            if contentPath.hasSuffix("Assets.car") {
                (imageSets, dataSets) = AssetsCarTool.parseAssets(path: contentPath)
            }

            let name = contentPath.split(separator: "/").last!
            let fileSize = FileTool.getFileSize(path: contentPath)
            let file = File(name: String(name), path: contentPath, size: Int(fileSize))
            files.append(file)
        }
        return ResourceBundle(name: bundleName, files: files, imageSets: imageSets, datasets: dataSets)
    }
}

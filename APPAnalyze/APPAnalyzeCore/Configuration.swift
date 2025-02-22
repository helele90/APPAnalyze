//
//  APPAnalyze.shared.configswift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/5.
//

import Foundation
import SwiftyJSON

public class Configuration {

    public var currentDirectoryPath: String!

    private(set) var otoolPath = ""

    private(set) var sizePath = ""

    private(set) var assetutilPath = ""
    
    /// 自定义配置文件路径
    public var configPath: String?
    
    public private(set) var customConfig: JSON?
    
    /// 默认值为 arm64
    public var archType: ArchType = .arm64
    
    /// 输出参数文件夹
    public var reportOutputPath: String!

    func check() {
        //
        if APPAnalyze.shared.parser == nil {
            fatalError("需要设置 parser")
        }
        //
        if currentDirectoryPath.isEmpty {
            fatalError("currentDirectoryPath参数错误")
        }
        // 解析自定义配置
        if let configPath = configPath {
            do {
                let data = try NSData(contentsOfFile: configPath) as Data
                customConfig = JSON(data)
            } catch {
                print("config路径错误或格式不正确")
            }
        }
        //
        if reportOutputPath.isEmpty {
            fatalError("reportOutputPath路径错误")
        }
        //
        let xcodePath = Command.shell(in: currentDirectoryPath, launchPath: "/usr/bin/xcode-select", arguments: ["-p"])
        //
        otoolPath = "\(xcodePath)/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool"
        sizePath = "\(xcodePath)/Toolchains/XcodeDefault.xctoolchain/usr/bin/size"
        assetutilPath = "\(xcodePath)/Toolchains/XcodeDefault.xctoolchain/usr/bin/assetutil"
        //
        if !FileManager.default.fileExists(atPath: otoolPath) {
            otoolPath = "/usr/bin/otool"
        }
        if !FileManager.default.fileExists(atPath: sizePath) {
            sizePath = "/usr/bin/size"
        }
        if !FileManager.default.fileExists(atPath: assetutilPath) {
            assetutilPath = "/usr/bin/assetutil"
        }
        print("otool环境地址：\(otoolPath)")
        print("size环境地址：\(sizePath)")
        print("assetutil环境地址：\(assetutilPath)")
    }
}

public extension Configuration {
    var rules: JSON? {
        return customConfig?["rules"]
    }
}

//
//  FileTool.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/5.
//

import CommonCrypto
import Foundation

public enum FileTool {
    /// 获取文件或目录大小
    /// - Parameter path: 文件或目录路径
    /// - Returns: Byte大小
    static func getSize(path: String) -> Int {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            return getDirectorySize(path: path)
        } else {
            return getFileSize(path: path)
        }
    }

    /// 文件大小
    /// - Parameter path: 文件路径
    /// - Returns: Byte大小
    static func getFileSize(path: String) -> Int {
        let attributes = try! FileManager.default.attributesOfItem(atPath: path)
        return Int(attributes[FileAttributeKey.size] as! UInt64)
    }

    /// 目录文件总大小
    /// - Parameter path: 目录文件路径
    /// - Returns: Byte大小
    static func getDirectorySize(path: String) -> Int {
        var size = 0
        let subpaths = FileManager.default.subpaths(atPath: path) ?? []
        for subpath in subpaths {
            let subpath2 = "\(path)/\(subpath)"
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: subpath2, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                size += getDirectorySize(path: subpath2)
            } else {
                size += getFileSize(path: subpath2)
            }
        }
        return size
    }

    /// 获取文件 MD5
    /// - Parameter path: 文件路径
    /// - Returns: 文件MD5
    public static func getMD5(path: String) -> String? {
        guard let file = FileHandle(forReadingAtPath: path) else {
            return nil
        }

        let bufferSize = 1024 * 1024
        // 打开文件
        defer {
            file.closeFile()
        }

        // 初始化内容
        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)

        // 读取文件信息
        while case let data = file.readData(ofLength: bufferSize), data.count > 0 {
            data.withUnsafeBytes {
                _ = CC_MD5_Update(&context, $0, CC_LONG(data.count))
            }
        }

        // 计算Md5摘要
        var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes {
            _ = CC_MD5_Final($0, &context)
        }

        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

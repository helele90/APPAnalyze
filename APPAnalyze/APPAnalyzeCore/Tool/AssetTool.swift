//
//  AssetTool.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/28.
//

import Foundation

struct AssetsItem: Decodable {
    let AssetType: String?
    let Name: String?
    let RenditionName: String?
    let SizeOnDisk: Int?
    let Scale: Int?
    let DeploymentTarget: String?
}

/// 字符串 PackedAssetImage
public let PackedAssetImage = "PackedAssetImage"

enum AssetsCarTool {
    private static func getAssetsInfo(path: String) -> [AssetsItem] {
        let output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: "/usr/bin/assetutil", arguments: ["--info", path], encoding: .isoLatin1)
        let data = output.data(using: .utf8)!
        //
        let decoder = JSONDecoder()
        let assets = try! decoder.decode([AssetsItem].self, from: data)
        return assets
    }

    /// 解析Assets.car
    /// - Parameter path: Assets.car 目录
    /// - Returns: imageset 和 dataset 集合
    static func parseAssets(path: String) -> (Set<ResourceImageSet>, Set<ResourceDataSet>) {
        var imageSets: Set<ResourceImageSet> = []
        var dataSets: Set<ResourceDataSet> = []
        let assets = getAssetsInfo(path: path)
        //
        var images: [ResourceImageSetImage] = []
        var imageSetName = ""
        var imageScales: Set<Int> = []
        //
        let assetsCarName = URL(string: path)!.lastPathComponent
        //
        var packedImageSize = 0
        //
        for asset in assets {
            guard let SizeOnDisk = asset.SizeOnDisk else {
                continue
            }

            let assetType = asset.AssetType
            if assetType == "Data" { // DataSet
                if let Name = asset.Name {
                    let item = ResourceDataSetItem(filename: Name, idiom: nil, size: SizeOnDisk, path: nil)
                    let dataSet = ResourceDataSet(name: Name, data: [item], assetsCar: nil)
                    dataSets.insert(dataSet)
                }
            } else if assetType == "Image" { // ImageSet
                if let Name = asset.Name, let Scale = asset.Scale, let RenditionName = asset.RenditionName {
                    //
                    if !imageSetName.isEmpty, imageSetName != Name {
                        let imageSet = ResourceImageSet(name: imageSetName, images: images, assetsCar: assetsCarName)
                        imageSets.insert(imageSet)
                        //
                        images.removeAll()
                        imageScales.removeAll()
                    }
                    //
                    if !imageScales.contains(Scale) {
                        let scale = ImagesetScale(scale: Scale)!
                        let image = ResourceImageSetImage(filename: RenditionName, scale: scale, size: SizeOnDisk, path: nil)
                        images.append(image)
                        //
                        imageScales.insert(Scale)
                    }
                    //
                    imageSetName = Name
                }
            } else if assetType == "Icon Image" {
            } else if assetType == "Color" {
            } else if assetType == "Vector" {
                
            } else if assetType == "PackedImage" {
                if asset.DeploymentTarget == nil {
                    packedImageSize += SizeOnDisk
                }
            } else {}
        }
        //
        if !images.isEmpty {
            let imageSet = ResourceImageSet(name: imageSetName, images: images, assetsCar: assetsCarName)
            imageSets.insert(imageSet)
        }
        //
        if packedImageSize > 0 {
            let image = ResourceImageSetImage(filename: PackedAssetImage, scale: .x3, size: packedImageSize, path: nil)
            let imageSet = ResourceImageSet(name: PackedAssetImage, images: [image], assetsCar: assetsCarName)
            imageSets.insert(imageSet)
        }
        //
        return (imageSets, dataSets)
    }
}

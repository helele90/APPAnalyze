//
//  XCAssetsTool.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/14.
//

import Foundation

struct ContentsJSONImage: Decodable {
    let scale: ImagesetScale?
    let filename: String?
}

struct ContentsJSON: Decodable {
    let images: [ContentsJSONImage]
}

struct ContentsJSONData: Decodable {
    let data: [ContentsJSONDataItem]
}

struct ContentsJSONDataItem: Decodable {
    let filename: String?
    let idiom: String
}

enum XCAssetsTool {
    static func parseAssets(path: String) -> (Set<ResourceImageSet>, Set<ResourceDataSet>) {
        let imageSetSubpaths = FileManager.default.subpaths(atPath: path) ?? []
        if imageSetSubpaths.isEmpty {
            return ([], [])
        }
        //
        var imageSets: Set<ResourceImageSet> = []
        var dataSets: Set<ResourceDataSet> = []
        //
        for subpath in imageSetSubpaths {
            let setPath = "\(path)/\(subpath)"
            if subpath.hasSuffix(".imageset") {
                if let imageSet = parseImageset(path: setPath) {
                    imageSets.insert(imageSet)
                }
            } else if subpath.hasSuffix(".dataset") {
                if let dataSet = parseDataset(path: setPath) {
                    dataSets.insert(dataSet)
                }
            }
        }

        return (imageSets, dataSets)
    }

    static func parseImageset(path: String) -> ResourceImageSet? {
        let imageSetSubpaths = FileManager.default.subpaths(atPath: path) ?? []
        if imageSetSubpaths.isEmpty {
            return nil
        }
        //
        let imageSetName = path.split(separator: "/").last!
        let endIndex = imageSetName.index(imageSetName.endIndex, offsetBy: -9)
        let imageSetName2 = String(imageSetName[imageSetName.startIndex ..< endIndex])
        //
        let contentJsonPath = "\(path)/Contents.json"
        guard let data = try? NSData(contentsOfFile: contentJsonPath) as Data else {
            return ResourceImageSet(name: imageSetName2, images: [], assetsCar: nil)
        }

        let decoder = JSONDecoder()
        let contents = try! decoder.decode(ContentsJSON.self, from: data)
        //
        var images: [ResourceImageSetImage] = []
        //
        for imageName in imageSetSubpaths {
            if !imageName.hasSuffix("Contents.json"), imageName != ".DS_Store" {
                let imageScale = contents.images.first(where: { $0.filename == imageName })?.scale
                //
                let imagePath = "\(path)/\(imageName)"
                let fileSize = FileTool.getFileSize(path: imagePath)
                //
                let image = ResourceImageSetImage(filename: imageName, scale: imageScale, size: Int(fileSize), path: imagePath)
                images.append(image)
            }
        }

        return ResourceImageSet(name: imageSetName2, images: images, assetsCar: nil)
    }

    static func parseDataset(path: String) -> ResourceDataSet? {
        let imageSetSubpaths = FileManager.default.subpaths(atPath: path) ?? []
        if imageSetSubpaths.isEmpty {
            return nil
        }

        //
        let imageSetName = path.split(separator: "/").last!
        let endIndex = imageSetName.index(imageSetName.endIndex, offsetBy: -8)
        let dataSetName = String(imageSetName[imageSetName.startIndex ..< endIndex])
        //
        let contentJsonPath = "\(path)/Contents.json"
        guard let data = NSData(contentsOfFile: contentJsonPath) as? Data else {
            let subpaths = FileManager.default.subpaths(atPath: path) ?? []
            guard !subpaths.isEmpty else {
                return nil
            }
            //
            var images: [ResourceDataSetItem] = []
            for subpath in subpaths {
                let imagePath = "\(path)/\(subpath)"
                let fileSize = FileTool.getFileSize(path: imagePath)
                //
                let image = ResourceDataSetItem(filename: subpath, idiom: nil, size: Int(fileSize), path: imagePath)
                images.append(image)
            }
            //
            let dataSet = ResourceDataSet(name: dataSetName, data: images, assetsCar: nil)
            return dataSet
        }
        let decoder = JSONDecoder()
        let contents = try! decoder.decode(ContentsJSONData.self, from: data)
        //
        var images: [ResourceDataSetItem] = []
        //
        for imageName in imageSetSubpaths {
            if !imageName.hasSuffix("Contents.json"), imageName != ".DS_Store" {
                let idiom = contents.data.first(where: { $0.filename == imageName })?.idiom
                //
                let imagePath = "\(path)/\(imageName)"
                let fileSize = FileTool.getFileSize(path: imagePath)
                //
                let image = ResourceDataSetItem(filename: imageName, idiom: idiom, size: Int(fileSize), path: imagePath)
                images.append(image)
            }
        }
        //
        return ResourceDataSet(name: dataSetName, data: images, assetsCar: nil)
    }
}

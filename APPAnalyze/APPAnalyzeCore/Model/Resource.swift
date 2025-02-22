//
//  Resource.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/14.
//

import Foundation

public struct File: Hashable {
    public let name: String
    public let path: String
    public let size: Int

    public init(name: String, path: String, size: Int) {
        self.name = name
        self.path = path
        self.size = size
    }
}

public struct ResourceBundle {
    public let name: String
    public let files: [File]
    public let imageSets: Set<ResourceImageSet>
    public let datasets: Set<ResourceDataSet>

    public init(name: String, files: [File], imageSets: Set<ResourceImageSet>, datasets: Set<ResourceDataSet>) {
        self.name = name
        self.files = files
        self.imageSets = imageSets
        self.datasets = datasets
    }
}

public struct ComponentResource {
    public let bundles: [ResourceBundle]
    let size: Int

    public init(bundles: [ResourceBundle], size: Int) {
        self.bundles = bundles
        self.size = size
    }
}

public enum ImagesetScale: String, Decodable {
    case x1 = "1x"
    case x2 = "2x"
    case x3 = "3x"

    init?(scale: Int) {
        switch scale {
        case 1:
            self = .x1
        case 2:
            self = .x2
        case 3:
            self = .x3
        default:
            return nil
        }
    }
}

public struct ResourceDataSet: Hashable {
    public let name: String
    public let data: [ResourceDataSetItem]
    public let assetsCar: String?

    public var size: Int {
        return data.filter { $0.idiom != nil }.max(by: { $0.size > $1.size }).map { $0.size } ?? 0
    }
}

public struct ResourceDataSetItem: Hashable {
    public let filename: String
    let idiom: String?
    public let size: Int
    public let path: String?
}

public struct ResourceImageSet: Hashable {
    public let name: String
    public let images: [ResourceImageSetImage]
    public let assetsCar: String?
}

public extension ResourceImageSet {
    var size: Int {
        let image3 = images.first(where: { $0.scale == .x3 })
        if let image3 = image3 {
            return image3.size
        }
        //
        let image2 = images.first(where: { $0.scale == .x2 })
        if let image2 = image2 {
            return image2.size
        }
        //
        let image1 = images.first(where: { $0.scale == .x1 })
        if let image1 = image1 {
            return image1.size
        }
        //
        return 0
    }
}

public struct ResourceImageSetImage: Hashable {
    public let filename: String
    public let scale: ImagesetScale?
    public let size: Int
    public let path: String?
}

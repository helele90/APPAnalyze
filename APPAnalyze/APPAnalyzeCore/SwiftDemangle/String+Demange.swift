//
//  String+Demange.swift
//  SwiftDemangle
//
//  Created by hexiao on 2023/8/19.
//

import Foundation

extension String {
    
    public func classDemangling() -> [String] {
        var mangled = self
        if mangled.hasPrefix("S") || mangled.hasPrefix("s") {
            mangled = "$" + mangled
        }
        return mangled.classDemangleSymbolAsString()
    }
    
}

extension Node {
    
    private func test(node: Node) -> String {
        guard node.kind == .Class else {
            return ""
        }
        
        var identifiers: [String] = []
        var module = ""
        var _children = node._children
        while !_children.isEmpty {
            let identifier = _children.first(where: { $0.kind == .Identifier })?.text ?? ""
            if _children[0].kind == .Module {
                module = _children[0].text
                //
                if !identifier.isEmpty {
                    identifiers.insert(identifier, at: 0)
                }
                //
                if _children.count > 1, _children[1].kind == .PrivateDeclName {
                    let b = _children[1]._children[0].text
                    let c = _children[1]._children[1].text
                    let d = "(\(c) in \(b))"
                    identifiers.append(d)
                }
                //
                _children = []
            } else if _children[0].kind == .Class || _children[0].kind == .Structure {
                //
                if !identifier.isEmpty {
                    identifiers.append(identifier)
                }
                //
                _children = _children[0]._children
            } else {
                _children = []
            }
        }
        if module == "__C" {
            module = ""
        }
        //
        let name = identifiers.joined(separator: ".")
        let classType = module.isEmpty ? name : "\(module).\(name)"
        return classType
    }
    
    var classNames: [String] {
        var classlist: Set<String> = []
        var children: [Node] = _children
        while !children.isEmpty {
            var nextChildren: [Node] = []
            for child in children {
                if child.kind == .Class {
                    let className = test(node: child)
                    classlist.insert(className)
                } else {
                    nextChildren.append(contentsOf: child._children)
                }
            }
            //
            children = nextChildren
        }
        
        return Array(classlist)
    }
    
}

extension Demangling where Self: StringProtocol, Self: Mangling {
    
    internal func classDemangleSymbolAsString() -> [String] {
        let root = demangleSymbolAsNode()
        return root?.classNames ?? []
    }
    
}

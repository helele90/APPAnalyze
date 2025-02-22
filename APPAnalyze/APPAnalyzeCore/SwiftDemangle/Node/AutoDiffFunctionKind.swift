//
//  AutoDiffFunctionKind.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/14.
//

import Foundation

enum AutoDiffFunctionKind: String {
  case JVP = "f"
  case VJP = "r"
  case Differential = "d"
  case Pullback = "p"
};

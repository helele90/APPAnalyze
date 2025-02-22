//
//  FixedWidthInteger+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/05/20.
//

import Foundation

extension FixedWidthInteger {
    
    func to<To>() -> To where To: FixedWidthInteger {
        To(self)
    }
    
}

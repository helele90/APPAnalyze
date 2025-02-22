//
//  Equatable+Extension.swift
//  Demangling
//
//  Created by spacefrog on 2021/06/02.
//

import Foundation

extension Equatable {
    
    func notEqualOrNil(_ e: Self) -> Self? {
        if self != e {
            return self
        } else {
            return nil
        }
    }
    
}

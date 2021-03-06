//
//  DictionaryInitExtension.swift
//  EasyLogin
//
//  Created by Frank on 15/05/17.
//
//

import Foundation

public extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        for (k, v) in pairs {
            self[k] = v
        }
    }
}

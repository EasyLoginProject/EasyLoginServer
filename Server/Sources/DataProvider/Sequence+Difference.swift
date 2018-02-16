//
//  Sequence+Difference.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 10/02/2018.
//

import Foundation

extension Sequence where Element: Hashable {
    public func difference(from initial: Self) -> (added: Set<Element>, removed: Set<Element>) {
        let initialSet = Set(initial)
        let finalSet = Set(self)
        let addedSet = finalSet.subtracting(initialSet)
        let removedSet = initialSet.subtracting(finalSet)
        return (addedSet, removedSet)
    }
}

//
//  Blocking.swift
//  Application
//
//  Created by Frank on 19/04/2018.
//

import Foundation
import Dispatch

struct Blocking<T> {
    typealias SuccessFunc = (T) -> Void
    typealias FailureFunc = (Error) -> Void
    
    static func call(asyncFunction:(@escaping SuccessFunc, @escaping FailureFunc) -> Void) throws -> T {
        let semaphore = DispatchSemaphore(value:0)
        var result: T?
        var error: Error?
        asyncFunction({
            result = $0
            semaphore.signal()
        }, {
            error = $0
            semaphore.signal()
        })
        semaphore.wait()
        if let result = result {
            return result
        }
        throw error!
    }
}


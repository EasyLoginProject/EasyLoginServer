//
//  CodableRouterExtensionForLDAP.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 30/12/2017.
//

import Foundation
import Kitura
import KituraContracts
import KituraNet
import LoggerAPI

extension Router {
    
    // In the original post implementation, it was impossible to send custom body and status code
    func ldapPOST<I: Codable, O: Codable>(_ route: String, handler: @escaping CodableClosure<I, O>) {
        post(route) { request, response, next in
            Log.verbose("Received POST type-safe request")
            
            guard let contentType = request.headers["Content-Type"] else {
                response.status(.unsupportedMediaType)
                next()
                return
            }
            guard contentType.hasPrefix("application/json") else {
                response.status(.unsupportedMediaType)
                next()
                return
            }

            do {
                // Process incoming data from client
                let param = try request.read(as: I.self)
                
                // Define handler to process result from application
                let resultHandler: CodableResultClosure<O> = { result, error in
                    do {
                        // Specific implementation needed to be able to provide POST answer with ErrorCode
                        if let result = result {
                            if let error = error {
                                let status = HTTPStatusCode(rawValue: error.rawValue) ?? .unknown
                                response.status(status)
                            } else {
                                response.status(.OK)
                            }
                            
                            let encoded = try JSONEncoder().encode(result)
                            response.headers.setType("json")
                            response.send(data: encoded)
                            
                        } else {
                            if let error = error {
                                let status = HTTPStatusCode(rawValue: error.rawValue) ?? .unknown
                                response.status(status)
                            } else {
                                response.status(.internalServerError)
                            }
                        }
                    } catch {
                        // Http 500 error
                        response.status(.internalServerError)
                    }
                    next()
                }
                // Invoke application handler
                handler(param, resultHandler)
            } catch {
                // Http 400 error
                //response.status(.badRequest)
                // Http 422 error
                response.status(.unprocessableEntity)
                next()
            }
        }
    }
}

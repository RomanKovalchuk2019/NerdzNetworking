//
//  RequestType.swift
//  Networking
//
//  Created by new user on 25.01.2020.
//  Copyright © 2020 Vasyl Khmil. All rights reserved.
//

import Foundation

fileprivate enum RequestInternalError: Error {
    case defaultEndpointIsNotInitialized

    var localizedDescription: String {
        switch self {
        case .defaultEndpointIsNotInitialized: 
            return "Default endpoint is not initialized"
        }
    }
}

public protocol Request: RequestData {
    associatedtype ResponseObjectType: Decodable
    associatedtype ErrorType: ServerError
    
    var responseConverter: ResponseJsonConverter? { get }
    var errorConverter: ResponseJsonConverter? { get } 
    
    var endpoint: Endpoint? { get }
    
    var decoder: JSONDecoder? { get }
}

public extension Request {
    var responseConverter: ResponseJsonConverter? { 
        nil
    }
    
    var errorConverter: ResponseJsonConverter? { 
        nil
    } 
    
    var endpoint: Endpoint? {
        nil
    }
    
    var decoder: JSONDecoder?  {
        nil
    }
}

extension Request {
    public typealias ResponseSuccessCallback = (ResponseObjectType) -> Void
    public typealias ErrorCallback = (ErrorResponse<ErrorType>) -> Void

    var data: RequestData {
        self
    }

    @discardableResult
    public func execute(on endpoint: Endpoint) -> ExecutionOperation<Self> {
        endpoint.execute(self)
    }
    
    @discardableResult
    public func execute() -> ExecutionOperation<Self> {
        if let endpoint = self.endpoint ?? Endpoint.default {
            return execute(on: endpoint)
        } 
        else {
            let operation = ExecutionOperation<Self>(request: self)

            let queue = OperationQueue.current?.underlyingQueue ?? .main
            
            queue.async {
                operation.callOnFail(with: .system(RequestInternalError.defaultEndpointIsNotInitialized))
            }
            
            return operation
        }
    }
}

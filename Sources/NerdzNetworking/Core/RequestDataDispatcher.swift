//
//  URLSessionNetworkDispatcher.swift
//  Networking
//
//  Created by Vasyl Khmil on 21.01.2020.
//  Copyright © 2020 Vasyl Khmil. All rights reserved.
//

import Foundation
import TrustKit

class RequestDataDispatcher: NSObject, URLSessionDataDelegate {
    // MARK: - Errors
    
    private enum RequestDataDispatcher: Error {
        case invalidResponse
        
        var localizedDescription: String {
            switch self {
            case .invalidResponse: 
                return "Response is invalid"
            }
        }
    }
    
    // MARK: - Properties(Public)
    
    let requestFactory: RequestFactory
    let configuration: URLSessionConfiguration
    
    var trustKit: TrustKit?
    
    private(set) lazy var session: URLSession = {
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main) 
    }()
    
    init(requestFactory: RequestFactory, sessionConfiguration: URLSessionConfiguration = .default) {
        self.configuration = sessionConfiguration
        self.requestFactory = requestFactory
    }
    
    // MARK: - Properties(Private)
    
    private var progressClosures: [URLSessionTask: (Double) -> Void] = [:]
    
    func dispatch(
        _ requestData   : RequestData, 
        onSuccess       : ((Data?, Int) -> Void)? = nil, 
        onError         : ((Error) -> Void)? = nil,
        onProgress      : ((Double) -> Void)? = nil,
        onDebug         : ((DebugInfo) -> Void)? = nil) throws 
        
        -> DispatchOperation 
    {
        let request = try requestFactory.request(from: requestData)
        
        let requestStartDate = Date()
        
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else {
                return
            }
            
            let debugInfo = DebugInfo(
                sessionConfiguration: self.session.configuration, 
                request             : request, 
                dataResponse        : data, 
                urlResponse         : response as? HTTPURLResponse, 
                errorResponse       : error, 
                requestDuration     : Date().timeIntervalSince(requestStartDate),
                cURL                : request.cURL)
            
            onDebug?(debugInfo)
            
            if let error = error {
                onError?(error)
                return
            }
            
            if let httpUrlResponse = response as? HTTPURLResponse {
                
                if requestData.shouldCache {
                    if let data = data {
                        let object = CachedURLResponse(response: httpUrlResponse, data: data)
                        URLCache.shared.storeCachedResponse(object, for: request)
                    }
                    else {
                        URLCache.shared.removeCachedResponse(for: request)
                    }
                }
                
                onSuccess?(data, httpUrlResponse.statusCode)
            }
            else {
                onError?(RequestDataDispatcher.invalidResponse)
            }
        }
        
        if let progressClosure = onProgress {
            progressClosures[task] = progressClosure
        }
        
        task.resume()
        
        return task
    }
    
    func cahcedResponse(for requestData: RequestData) throws -> Data? {
        let request = try requestFactory.request(from: requestData)
        return URLCache.shared.cachedResponse(for: request)?.data
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let closure = progressClosures[task] {
            let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            closure(progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let validator = trustKit?.pinningValidator
        
        if validator?.handle(challenge, completionHandler: completionHandler) != true {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

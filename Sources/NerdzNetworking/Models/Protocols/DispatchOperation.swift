//
//  RequestOperation.swift
//  Networking
//
//  Created by new user on 25.01.2020.
//  Copyright © 2020 Vasyl Khmil. All rights reserved.
//

import Foundation

public protocol DispatchOperation {
    func cancel()
}

extension URLSessionDataTask: DispatchOperation { }

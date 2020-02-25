//
//  ContentHeader.swift
//  Networking
//
//  Created by new user on 24.01.2020.
//  Copyright © 2020 Vasyl Khmil. All rights reserved.
//

import Foundation

public enum ContentHeader: NetworkingHeader {
    case contenType(_ mime: MimeType, boundary: String? = nil)
    case accept(_ mime: MimeType)
    case length(_ length: Int)

    public var key: String {
        switch self {
        case .contenType: return "Content-Type"
        case .accept: return "Accept"
        case .length: return "Content-Length"
        }
    }
    
    public var value: String {
        switch self {
        case .length(let value): 
            return "\(value)"
            
        case .accept(let mime): 
            return mime.value
            
        case .contenType(let mime, let boundary):
            var value = mime.value
            
            if let boundary = boundary {
                value += "; boundary=\(boundary)" 
            }
            
            return value
        }
    }
}

# NerdzNetworking

`NerdzNetworking` is a wrapper on top of `URLSession` and `URLRequest` to simplify creating and managing network requests written on `Swift` language.

# Example

You need to define request.

```swift
class LoginWithFacebookRequest: Request {
    typealias ResponseObjectType = User
    typealias ErrorType = AuthError
    
    let path = "login/facebook"
    let methong = .post
    let bodyParams: [String: Any]
    
    init(token: String) {   
        bodyParams = ["token": token]
    }
}
```

And then just use it.

```swift
LoginWithFacebookRequest(token: fbToken)
    .execute()
    
    .onSuccess { user in
        ...
    }
    
    onError { error in
        ...
    }
}
```

# Ideology

The main ideology for creating `NerdzNetworking` library was to maximaly split networking into small pieces. 
The ideal scenario would be to have a separate class/structure per each request. This should help easily navigate and search information for specific request in files structure. 

![Requests example](https://raw.githubusercontent.com/nerdzlab/NerdzNetworking/master/requests_example.png)

# Tutorial

## Endpoint setup

First of all you need to setup your endpoint that will be used later on for executing requests. To do that - you should be using `Endpoint` class.
`Endpoint` class will collect all general settings for performing requests. You can change any parameter at any time you want.

```swift
let myEndpoint = Endpoint(baseUrl: myBaseUrl)
myEndpoint.headers = defaultHeaders // Specifying some default headers
myEndpoint.headers.contentType = .application(.json) // Specifying content type header
myEndpoint.headers.accept = .application(.json) // Specifying access header
myEndpoint.headers.authToken = .bearer(token) // Specifying auth token if such is required. PS: you can provide in later on
```

After creating your endpoint, you can mark it as a `default`, so every request will pick it up automatically.

```swift
Endpoint.default = myEndoint
```

You can change `default` endpoint based on configuration or environment you need.

## Request creation
To create a request you should implement `Request` protocol. You can or have separate class per each request or an `enum`.

### Separate class for each request

```swift
class MyRequest: Request {
    typealias ResponseObjectType = MyExpectedResponse
    typealias ErrorType = MyUnexpectedError
    
    let path = "my/path/to/backend" // Required
    let methong = .get // Optional
    let queryParams = [("key", "value")] // Optional
    let bodyParams = ["key", "value"] // Optional
    let headers = [RequestHeaderKey("key"): "value", .contentType: "application/json"] // Optional
    let timeout = 60 // Optional, by defauld will be picked from Endpoint
    let endpoint = myEndpoint // Optional, by default will be a Endpoint.default
}
```

This is just an example and probably you will not have all parameters required and static. To have dynamicaly created request - you can just use initializers that willl be taking dynamic parameters required for request. 
As an example - some dynamic bodyParams or dynamic path.

### Default request

You can use buit in class `DefaultRequest` to perform requests without a need to create a separate class.

```swift
let myRequest = DefaultRequest<MyExpectedResponse, MyUnexpectedError>(
    path: "my/path/to/backend", 
    method: .get, 
    queryParams: [("key", "value")], 
    bodyParams: ["key", "value"], 
    headers: [RequestHeaderKey("key"): "value", .contentType: "application/json"], 
    timeout: 60,
    responseConverter: myResponseConverter,
    errorConverter: myErrorConverter,
    endpoint: myEndpoint)
```

### Multipart request

`NerdzNetworking` library also provide an easy way of creation and execution of multipart form-data requests. You just need to implement `MultipartFormDataRequest` instead of `Request` protocol or use `DefaultMultipartFormDataRequest` class.

In addition to `Request` fields you will need to provide `files` field of `MultipartFile` protocol instances. You can implement this protocol or use `DefaultMultipartFile` class.

```swift
class MyMultipartRequest: MultipartFormDataRequest {
    // Same fields as in Request example
    
    let files: [MultipartFile] = [
        DefaultMultipartFile(resource: fileData, mime: .image(.png), fileName: "avatar1"),
        DefaultMultipartFile(resource: fileUrl, mime: .audio(.mp4), fileName: "song"),
        DefaultMultipartFile(resource: filePath, mime: .image(.jpeg), fileName: "avatar2")
    ]
}
```

## Request execution

To exucute request you can use next constructions:

- `myRequest.execute()`: will execute `myRequest` on `Endpoint.default`
- `myRequest.execute(on: myEndpoint)`: will execute `myRequest` on `myEndpoint`
- `myEndpoint.execute(myRequest)`: will execute `myRequest` on `myEndpoint`

### Handling execution process

To handle execution process you can use futures-style methods after `execute` method called.

```swift
myRequest
    .execute()
    .responseOn(.main) // Response will be returned in `.main` queue
    .retryOnFail(false) // If this request will fail - system will not try to rerun it again
    .onStart { requestOperation in
        // Will be called when request will start and return request operation that allow to control request during the execution
    }
    .onSuccess { response in
        // Will return a response object specified in request under `ResponseType`
    }
    .onFail { error in
        // Will return `ErrorResponse` that might contain `ErrorType` specified in request
    }
    .onDebug { info in
        // Will return `DebugInfo` that contain a list of useful information for debugging request failure 
    }
```

## Mapping

For now `NerdzNetworking` library support custom mapping or `Decodable` approach. Later on we plan to add `ObjectMapper` library as well.

### ResponseObject

Every response should be implementing `ResponseObject` protocol.

Some of the default classes implement it dirrectly from the box, so you can use them as a response without extra efort.

- All scalars [`Double`, `Float`, `Bool`, `Int`, `Int8`,  `Int16`, `Int32`,  etc...]
- `Data`: will return raw bytes of the response
- `String`: will return response as a string (very good for debugging as it will not fail on mapping)
- `[ResponseObject]`: you can provide an array as a response if his elements conform to `ResponseObject` protocol
- `ResponseObject?`: you can provide an optional `ResponseObject` in case you do not know if server will return you something or not
- `[String: ResponseObject]`: similar to arrays, you can provide a dictionary as a response if values respond to `ResponseObject` protocol

### `Decodable`

To use `Decodable` protocol you need your response class to conform `ResponseObject & Decodable` or `DecodableResponseObject`.

We recommend to use `DecodableResponseObject` as than you get more flexibility by providing custom `JSONDecoder` for each response.

```swift
class MyResponse: DecodableResponseObject {
    var decoder: JSONDecoder {
        myCustomJSONDecoder
    }
    
    init(from decoder: Decoder) throws {
        // Decodable mapping
    }
}
```

### Custom object mapping

To have custom mapping you should be using `CustomObjectMapper` class or implement your own class inherited from `BaseObjectMapper`.

If you decide to go with custom mapping - you will need to provide mapping from `JSON(Any)` and from `Data`. This is because `NerdzNetworking` library works not only with `JSON` response, but support also scalars, data, string, etc.

You can provide your custom mapper in `ResponseObject` class under `mapper` field.

```swift
class MyResponse: ResponseObject {
    var mapper: BaseObjectMapper<Self> {
        return CustomObjectMapper<Self>(
            jsonClosure: {
                // Return object or nil based on iput json
            },
            
            dataClosure: {
                // Return object or nil based on input data
            }
        )
    }
}
```

### `ResponseJsonConverter`

You can also provide a response converters to convert some unpropertly returned responses becore mapping into expected response starts. The responsible protocol for this is `ResponseJsonConverter`.

Response converter should be specified in `Request` class under `responseConverter`(success) or/and `errorConverter`(fail).

You can have your own converters that implement `ResponseJsonConverter` protocol, or use built in implementations: `KeyPathResponseConverter`, `ClosureResponseConverter`.

#### `KeyPathResponseConverter`

`KeyPathResponseConverter` allow you to pull a data from `JSON` by specific `path` provided. 

```swift
class MyRequest: Request {
    var responseConverter: ResponseJsonConverter {
        KeyPathResponseConverter(path: "path/to/object")
    }
    
    var errorConverter: ResponseJsonConverter {
        KeyPathResponseConverter(path: "path/to/error")
    }
}
```

#### `ClosureResponseConverter`

`ClosureResponseConverter` allow you to provide custom convertation. You will need to provide a `closure` that takes `Any` and return `Any` after convertation.

```swift
class MyRequest: Request {
    var responseConverter: ResponseJsonConverter {
        ClosureResponseConverter { response in
            // Return converted response for success response
        }
    }
    
    var errorConverter: ResponseJsonConverter {
        ClosureResponseConverter { response in
            // Return converted response for error response
        }
    }
}
```

#### Custom `ResponseJsonConverter`

You can implement your ovn converter by implementing `ResponseJsonConverter` protocol.

```swift
class MyResponseConverter: ResponseJsonConverter {
    func convertedJson(from json: Any) throws -> Any {
        // Provide convertation and return converted code
    }
}
```

# Installation


## CocoaPods

You can use [CocoaPods](https://cocoapods.org) dependency manager to install `NerdzNetworking`.
In your `Podfile` spicify:

```ruby
pod 'NerdzNetworking', '~> 0.0'
```


## Swift Package Manager

To add NerdzNetworking to a [Swift Package Manager](https://swift.org/package-manager/) based project, add:

```swift
.package(url: "https://github.com/nerdzlab/NerdzNetworking")
```

# Docummentation


## `Endpoint` class

Class that represents and endpoint with all settings for requests execution. You need to create at least one instance to be able to execute requests.

### Properties

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`Endpoint.default` | `Endpoint` | `static` `read-write` | An instance of endpoint that will be used for executing request
`baseUrl` | `URL` | `readonly` | An endpoint base url
`sessionConfiguration` | `URLSessionConfiguration` | `readonly` | A configuration that is used for inner `URLSession`
`headers` | `[RequestHeaderKey: String]` | `read-write` | A headers that will be used with every request

### Methods

* `init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration = .default, contentType: MimeType = .application(.json), accept: MimeType = .application(.json), token: AuthToken? = nil, additionalHeaders: [RequestHeader] = [])`

*Initializing with all parameters*

Name | Type | Default value | Description
------------ | ------------ | ------------- | -------------
`baseUrl` | `URL` | - | An endpoint base url
`sessionConfiguration`| `URLSessionConfiguration` | `.default` | A configuration that will be used for inner `URLSession`
`headers` | `[RequestHeaderKey: String]` | `[:]` | A headers that will be used with every request 

* `func execute<T: Request>(_ request: T) -> ResponseInfoBuilder<T>`

*Executing request on current endpoint*

Name | Type | Default value | Description
------------ | ------------ | ------------- | -------------
`request` | `Request` | - | Request to be executed


## `Request` protocol

**TYPE**: `protocol`

Protocol that represents a single request. You can imlement this protocol and then execute it

### `associatedtype`

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`ResponseObjectType` | `ResponseObject` | A type of expected response from server. It should implement `ResponseObject` protocol 
`ErrorType` | `ServerError` | A type of expected error from server. It should implement `ServerError` protocol 

### Properties

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`path` | `String` | `get` `required` | A request path
`method` | `HTTPMethod` | `get` `required` | A request method
`queryParams` | `[(String, String)]` | `get` `optional` | A request query parameters represented as an array of touples to save order
`bodyParams` | `[String: Any]` | `get` `optional` | A request body params
`headers` | `[RequestHeaderKey: String]` | `get` `optional` | A request specific headers. Will be used is addition to headers from `Endpoint`
`timeout` | `TimeInterval` | `get` `optional` | A request timeout. If not specified - will be used default from `Endpoint`
`responseConverter` | `ResponseJsonConverter?` | `get` `optional` | A successful response converter. Will be converted before mapping into a `ResponseObjectType`
`errorConverter` | `ResponseJsonConverter?` | `get` `optional` | An error response converter. Will be converted before mapping into a `ErrorType`
`endpoint` | `Endpoint?` | `get` `optional` | An endpoint that will be used for execution

### Methods

* `func execute(on endpoint: Endpoint) -> ResponseInfoBuilder<Self>`

*Executing current request on provided endpoint*

Name | Type | Default value | Description
------------ | ------------ | ------------- | -------------
`endpoint` | `Endpoint` | - | Endpoint on what current request will be executed

* `func execute() -> ResponseInfoBuilder<Self>`

*Executing current request on endpoint provided in property or on `Endpoint.default`*


## `DefaultRequest` struct

**TYPE**: `struct`
**IMPLEMENT**: `Request`

A default implementation of `Request` protocol that can be used for executing simple requests

### Generics

Name | Types | Description
------------ | ------------- | -------------
`Response` | `ResponseObject` | A type of a successful response object 
`Error` | `ServerError` | A type of an error response object

### Properties

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`path` | `String` | `read-write` | A request path
`method` | `HTTPMethod` | `read-write` | A request method
`queryParams` | `[(String, String)]` | `read-write` | A request query parameters represented as an array of touples to save order
`bodyParams` | `[String: Any]` | `read-write` | A request body params
`headers` | `[RequestHeaderKey: String]` | `read-write` | A request specific headers. Will be used is addition to headers from `Endpoint`
`timeout` | `TimeInterval` | `read-write` | A request timeout. If not specified - will be used default from `Endpoint`
`responseConverter` | `ResponseJsonConverter?` | `read-write` | A successful response converter. Will be converted before mapping into a `ResponseObjectType`
`errorConverter` | `ResponseJsonConverter?` | `read-write` | An error response converter. Will be converted before mapping into a `ErrorType`
`endpoint` | `Endpoint?` | `read-write` | An endpoint that will be used for execution

### Methods

* `init(path: String, method: HTTPMethod, queryParams: [(String, String)] = [], bodyParams: [String: Any] = [:], headers: [RequestHeader] = [], timeout: TimeInterval? = nil, responseConverter: ResponseJsonConverter? = nil, errorConverter: ResponseJsonConverter? = nil, endpoint: Endpoint? = nil)`

*Initialize `DefaultRequest` object with all possible parameters*

Name | Type | Default value | Description
------------ | ------------ | ------------- | -------------
`path` | `String` | - | A request path
`method` | `HTTPMethod` | - | A request method
`queryParams` | `[(String, String)]` | `[]` | A request query parameters represented as an array of touples to save order
`bodyParams` | `[String: Any]` | `[:]` | A request body params
`headers` | `[RequestHeaderKey: String]` | `[:]` | A request specific headers. Will be used is addition to headers from `Endpoint`
`timeout` | `TimeInterval` | `nil` | A request timeout. If not specified - will be used default from `Endpoint`
`responseConverter` | `ResponseJsonConverter?` | `nil` | A successful response converter. Will be converted before mapping into a `ResponseObjectType`
`errorConverter` | `ResponseJsonConverter?` | `nil` | An error response converter. Will be converted before mapping into a `ErrorType`
`endpoint` | `Endpoint?` | `nil` | An endpoint that will be used for execution


## `MultipartFormDataRequest` protocol

**TYPE**: `protocol`
**INHERITS**: `Request`

A protocol that needs to be implemented in order to execute multipart form-data request.

### Properties

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`files` | `[MultipartFile]` | `get` `required` | A list of files to be included in request


## `DefaultMultipartFormDataRequest` struct

**TYPE**: `struct`
**IMPLEMENT**: `MultipartFormDataRequest`

A default implementation of `MultipartFormDataRequest` protocol that can be used for executing simple requests

### Generics

Name | Types | Description
------------ | ------------- | -------------
`Response` | `ResponseObject` | A type of a successful response object 
`Error` | `ServerError` | A type of an error response object

### Properties

Name | Type | Accessibility | Description
------------ | ------------- | ------------- | -------------
`path` | `String` | `read-write` | A request path
`method` | `HTTPMethod` | `read-write` | A request method
`queryParams` | `[(String, String)]` | `read-write` | A request query parameters represented as an array of touples to save order
`bodyParams` | `[String: Any]` | `read-write` | A request body params
`headers` | `[RequestHeaderKey: String]` | `read-write` | A request specific headers. Will be used is addition to headers from `Endpoint`
`timeout` | `TimeInterval` | `read-write` | A request timeout. If not specified - will be used default from `Endpoint`
`responseConverter` | `ResponseJsonConverter?` | `read-write` | A successful response converter. Will be converted before mapping into a `ResponseObjectType`
`errorConverter` | `ResponseJsonConverter?` | `read-write` | An error response converter. Will be converted before mapping into a `ErrorType`
`endpoint` | `Endpoint?` | `read-write` | An endpoint that will be used for execution

### Methods

* `init(path: String, method: HTTPMethod, queryParams: [(String, String)] = [], bodyParams: [String: Any] = [:], headers: [RequestHeader] = [], timeout: TimeInterval? = nil, responseConverter: ResponseJsonConverter? = nil, errorConverter: ResponseJsonConverter? = nil, endpoint: Endpoint? = nil)`

*Initialize `DefaultMultipartFormDataRequest` object with all possible parameters*

Name | Type | Default value | Description
------------ | ------------ | ------------- | -------------
`path` | `String` | - | A request path
`method` | `HTTPMethod` | - | A request method
`queryParams` | `[(String, String)]` | `[]` | A request query parameters represented as an array of touples to save order
`bodyParams` | `[String: Any]` | `[:]` | A request body params
`headers` | `[RequestHeaderKey: String]` | `[:]` | A request specific headers. Will be used is addition to headers from `Endpoint`
`timeout` | `TimeInterval` | `nil` | A request timeout. If not specified - will be used default from `Endpoint`
`responseConverter` | `ResponseJsonConverter?` | `nil` | A successful response converter. Will be converted before mapping into a `ResponseObjectType`
`errorConverter` | `ResponseJsonConverter?` | `nil` | An error response converter. Will be converted before mapping into a `ErrorType`
`endpoint` | `Endpoint?` | `nil` | An endpoint that will be used for execution
`file` | `[MultipartFile]` | `[]` | A list of files that will be sent together with request


## `HTTPMethod` enum

**TYPE**: `enum`
**INHERITS**: `String`

An enum that represents a request http method.

Name | Description
------------ | ------------
`get` | A `GET` http method
`post` | A `POST` http method
`put` | A `PUT` http method
`delete` | A `DELETE` http method
`path` | A `PATH` http method 


# Next steps

**TBD**

# License

This code is distributed under the MIT license. See the `LICENSE` file for more info.



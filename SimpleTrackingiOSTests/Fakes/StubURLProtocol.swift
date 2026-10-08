import Foundation
import Synchronization

/// 네트워크를 막고 미리 정한 응답을 돌려주는 URLProtocol.
/// Swift Testing은 테스트를 병렬로 돌리므로 세션마다 고유 ID 헤더를 붙여 핸들러를 구분한다.
final class StubURLProtocol: URLProtocol {
    enum Reply: Sendable {
        case response(status: Int, body: Data)
        case failure(URLError)
    }

    typealias Handler = @Sendable (URLRequest) -> Reply

    private static let idHeader = "X-Stub-ID"
    private static let handlers = Mutex<[String: Handler]>([:])

    /// 요청을 기록하고 `handler`로 응답하는 세션을 만든다.
    static func makeSession(recorder: RequestRecorder? = nil, handler: @escaping Handler) -> URLSession {
        let id = UUID().uuidString
        handlers.withLock { $0[id] = { request in
            recorder?.record(request)
            return handler(request)
        } }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [idHeader: id]
        return URLSession(configuration: configuration)
    }

    static func makeSession(status: Int, json: String, recorder: RequestRecorder? = nil) -> URLSession {
        makeSession(recorder: recorder) { _ in .response(status: status, body: Data(json.utf8)) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.idHeader),
              let handler = Self.handlers.withLock({ $0[id] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request) {
        case let .response(status, body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class RequestRecorder: Sendable {
    private let requests = Mutex<[URLRequest]>([])

    var all: [URLRequest] { requests.withLock { $0 } }
    var last: URLRequest? { all.last }

    func record(_ request: URLRequest) {
        requests.withLock { $0.append(request) }
    }
}

extension URLRequest {
    func queryValue(_ name: String) -> String? {
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == name }?.value
    }
}

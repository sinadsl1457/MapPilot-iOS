import Foundation
import Testing
@testable import MapPilot

struct SafeApiCallTests {
    @Test(arguments: [
        (401, DomainError.unauthorized),
        (403, DomainError.unauthorized),
        (429, DomainError.quotaExceeded),
        (500, DomainError.server(code: 500)),
        (404, DomainError.server(code: 404)),
    ])
    func mapsHTTPStatus(status: Int, expected: DomainError) async {
        let client = KakaoAPIClient(restAPIKey: "key", session: StubURLProtocol.makeSession(status: status, json: "{}"))

        await #expect(throws: expected) {
            try await client.searchKeyword(query: "카페", center: nil)
        }
    }

    @Test func mapsURLErrorToNetwork() async {
        let session = StubURLProtocol.makeSession { _ in .failure(URLError(.notConnectedToInternet)) }
        let client = KakaoAPIClient(restAPIKey: "key", session: session)

        await #expect(throws: DomainError.network) {
            try await client.searchKeyword(query: "카페", center: nil)
        }
    }

    @Test func mapsDecodingErrorToUnknown() async {
        let client = KakaoAPIClient(restAPIKey: "key", session: StubURLProtocol.makeSession(status: 200, json: #"{"oops": 1}"#))

        await #expect(throws: DomainError.unknown) {
            try await client.searchKeyword(query: "카페", center: nil)
        }
    }

    @Test func passesDomainErrorThrough() async {
        await #expect(throws: DomainError.emptyQuery) {
            try await safeApiCall { throw DomainError.emptyQuery }
        }
    }

    @Test func rethrowsCancellation() async {
        await #expect(throws: CancellationError.self) {
            try await safeApiCall { throw CancellationError() }
        }
    }

    @Test func urlCancelledOnCancelledTaskBecomesCancellation() async {
        let task = Task {
            try await safeApiCall {
                while !Task.isCancelled { await Task.yield() }
                throw URLError(.cancelled)
            }
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

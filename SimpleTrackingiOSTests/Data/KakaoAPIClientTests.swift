import Foundation
import Testing
@testable import SimpleTrackingiOS

struct KakaoAPIClientTests {
    @Test func searchSendsAuthorizationAndQuery() async throws {
        let recorder = RequestRecorder()
        let session = StubURLProtocol.makeSession(status: 200, json: #"{"documents": []}"#, recorder: recorder)
        let client = KakaoAPIClient(restAPIKey: "test-key", session: session)

        _ = try await client.searchKeyword(query: "강남 카페", center: Fixtures.cityHall)

        let request = try #require(recorder.last)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "KakaoAK test-key")
        #expect(request.url?.host() == "dapi.kakao.com")
        #expect(request.url?.path() == "/v2/local/search/keyword.json")
        #expect(request.queryValue("query") == "강남 카페")
        #expect(request.queryValue("x") == "126.9784")
        #expect(request.queryValue("y") == "37.5666")
        #expect(request.queryValue("size") == "15")
    }

    @Test func searchWithoutCenterOmitsCoordinates() async throws {
        let recorder = RequestRecorder()
        let session = StubURLProtocol.makeSession(status: 200, json: #"{"documents": []}"#, recorder: recorder)

        _ = try await KakaoAPIClient(restAPIKey: "k", session: session).searchKeyword(query: "카페", center: nil)

        let request = try #require(recorder.last)
        #expect(request.queryValue("x") == nil)
        #expect(request.queryValue("y") == nil)
    }

    @Test func directionsUsesLongitudeLatitudeOrder() async throws {
        let recorder = RequestRecorder()
        let session = StubURLProtocol.makeSession(status: 200, json: #"{"routes": []}"#, recorder: recorder)

        _ = try await KakaoAPIClient(restAPIKey: "k", session: session)
            .directions(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        let request = try #require(recorder.last)
        #expect(request.url?.host() == "apis-navi.kakaomobility.com")
        #expect(request.url?.path() == "/v1/directions")
        #expect(request.queryValue("origin") == "126.9784,37.5666")
        #expect(request.queryValue("destination") == "127.02764,37.49794")
        #expect(request.queryValue("priority") == "DISTANCE")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "KakaoAK k")
    }
}

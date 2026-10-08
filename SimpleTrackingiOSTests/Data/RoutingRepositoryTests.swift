import Testing
@testable import SimpleTrackingiOS

struct RoutingRepositoryTests {
    private func repository(json: String, recorder: RequestRecorder? = nil) -> RouteRepositoryImpl {
        RouteRepositoryImpl(client: KakaoAPIClient(restAPIKey: "k", session: StubURLProtocol.makeSession(status: 200, json: json, recorder: recorder)))
    }

    @Test func walkRequestUsesSeparateXYParameters() async throws {
        let recorder = RequestRecorder()
        let json = #"{"status":"OK","route":{"properties":{"totalDistance":100,"totalTime":80,"landingUrl":"x"},"legs":[]}}"#

        _ = try await repository(json: json, recorder: recorder).findWalkingRoute(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        let request = try #require(recorder.last)
        #expect(request.url?.host() == "dapi.kakao.com")
        #expect(request.url?.path() == "/v2/routing/walk")
        #expect(request.queryValue("start_x") == "126.9784")
        #expect(request.queryValue("start_y") == "37.5666")
        #expect(request.queryValue("end_x") == "127.02764")
        #expect(request.queryValue("end_y") == "37.49794")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "KakaoAK k")
    }

    @Test func walkFailureStatusThrows() async {
        await #expect(throws: DomainError.routeNotFound(reason: "TOO_FAR_AWAY")) {
            try await repository(json: #"{"status":"TOO_FAR_AWAY"}"#).findWalkingRoute(from: Fixtures.cityHall, to: Fixtures.gangnamStation)
        }
    }

    @Test func transitDecodesRealResponseShape() async throws {
        let recorder = RequestRecorder()
        let json = """
        {"status":"OK",
         "properties":{"total":1,"bus":0,"subway":1,"busAndSubway":0,"landingURL":"x"},
         "routes":[{"properties":{"type":"SUBWAY","totalDistance":25950,"totalTime":3573,"transfers":1,"fare":{"value":1850}},
           "steps":[
             {"properties":{"guidance":"수인분당선 (태평 > 왕십리)","type":"SUBWAY","distance":20100,"time":1980,
               "stops":[{"name":"태평"},{"name":"왕십리"}],"vehicles":[{"name":"수인분당선","type":"일반"}]},
              "path":{"points":[[127.13,37.44],[127.03,37.56]]}},
             {"properties":{"guidance":"왕십리역 환승","type":"WALKING","distance":88,"time":144,"stops":[{"name":"왕십리"}],"vehicles":null},
              "path":{"points":[[127.03,37.56],[127.031,37.561]]}}
           ]}]}
        """

        let routes = try await repository(json: json, recorder: recorder).findTransitRoutes(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        #expect(recorder.last?.url?.path() == "/v2/routing/publictraffic")
        #expect(routes.count == 1)
        #expect(routes[0].durationSeconds == 3_573)
        #expect(routes[0].legs.map(\.kind) == [.subway, .walk])
    }

    @Test func transitFailureStatusThrows() async {
        await #expect(throws: DomainError.destinationTooClose) {
            try await repository(json: #"{"status":"EQUAL_POINTS"}"#).findTransitRoutes(from: Fixtures.cityHall, to: Fixtures.gangnamStation)
        }
    }
}

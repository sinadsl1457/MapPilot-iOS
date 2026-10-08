import Testing
@testable import SimpleTrackingiOS

struct RouteRepositoryImplTests {
    private func repository(json: String) -> RouteRepositoryImpl {
        RouteRepositoryImpl(client: KakaoAPIClient(restAPIKey: "k", session: StubURLProtocol.makeSession(status: 200, json: json)))
    }

    @Test func emptyRoutesIsRouteNotFound() async {
        await #expect(throws: DomainError.routeNotFound(reason: "경로 응답이 비어 있음")) {
            try await repository(json: #"{"trans_id": "t", "routes": []}"#)
                .findRoute(from: Fixtures.cityHall, to: Fixtures.gangnamStation)
        }
    }

    @Test func nonZeroResultCodeIsRouteNotFoundWithMessage() async {
        let json = """
        {"trans_id": "t", "routes": [{"result_code": 104, "result_msg": "출발지와 도착지가 5 m 이내로 설정된 경우 경로를 탐색할 수 없음"}]}
        """
        await #expect(throws: DomainError.routeNotFound(reason: "출발지와 도착지가 5 m 이내로 설정된 경우 경로를 탐색할 수 없음")) {
            try await repository(json: json).findRoute(from: Fixtures.cityHall, to: Fixtures.gangnamStation)
        }
    }

    @Test func successMapsRoute() async throws {
        let json = """
        {
          "trans_id": "t",
          "routes": [{
            "result_code": 0, "result_msg": "길찾기 성공",
            "summary": {"distance": 9120, "duration": 1500, "fare": {"taxi": 13400, "toll": 0}},
            "sections": [{"distance": 9120, "duration": 1500, "roads": [
              {"name": "세종대로", "vertexes": [126.9785, 37.5660, 126.9790, 37.5650]},
              {"name": "강남대로", "vertexes": [127.0270, 37.4990]}
            ]}]
          }]
        }
        """

        let route = try await repository(json: json).findRoute(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        #expect(route == Route(
            points: [
                Fixtures.cityHall,
                GeoPoint(latitude: 37.5660, longitude: 126.9785),
                GeoPoint(latitude: 37.5650, longitude: 126.9790),
                GeoPoint(latitude: 37.4990, longitude: 127.0270),
                Fixtures.gangnamStation,
            ],
            distanceMeters: 9120,
            durationSeconds: 1500,
            taxiFare: 13_400,
            tollFare: 0
        ))
    }
}

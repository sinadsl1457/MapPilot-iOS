import Testing
@testable import SimpleTrackingiOS

struct RoutingMapperTests {
    @Test func pathPairsAreLongitudeThenLatitudeAndBrokenPairsDropped() {
        let points = RoutingMapper.points(PathDTO(points: [[127.1, 37.1], [127.2], [127.3, 37.3]]))
        #expect(points == [GeoPoint(latitude: 37.1, longitude: 127.1), GeoPoint(latitude: 37.3, longitude: 127.3)])
    }

    @Test func walkingRouteWrapsStepsWithOriginAndDestination() {
        let dto = WalkRouteDTO(
            properties: WalkRoutePropertiesDTO(totalDistance: 1_200, totalTime: 900),
            legs: [WalkLegDTO(steps: [
                WalkStepDTO(path: PathDTO(points: [[127.0, 37.0], [127.01, 37.01]])),
                WalkStepDTO(path: nil),
            ])]
        )

        let route = RoutingMapper.walkingRoute(dto, origin: Fixtures.cityHall, destination: Fixtures.gangnamStation)

        #expect(route.points == [
            Fixtures.cityHall,
            GeoPoint(latitude: 37.0, longitude: 127.0),
            GeoPoint(latitude: 37.01, longitude: 127.01),
            Fixtures.gangnamStation,
        ])
        #expect(route.distanceMeters == 1_200)
        #expect(route.durationSeconds == 900)
    }

    @Test func transitRouteMapsKindsFareAndLegs() {
        let dto = TransitRouteDTO(
            properties: TransitRoutePropertiesDTO(type: "BUS_AND_SUBWAY", totalDistance: 25_000, totalTime: 3_600, transfers: 1, fare: FareDTO(value: 1_850)),
            steps: [
                TransitStepDTO(
                    properties: TransitStepPropertiesDTO(
                        guidance: "수인분당선 (태평 > 왕십리)", type: "SUBWAY", distance: 20_000, time: 1_980,
                        stops: [NamedDTO(name: "태평"), NamedDTO(name: "모란"), NamedDTO(name: "왕십리")],
                        vehicles: [NamedDTO(name: "수인분당선"), NamedDTO(name: "수인분당선")]
                    ),
                    path: PathDTO(points: [[127.1, 37.4], [127.0, 37.5]])
                ),
                TransitStepDTO(
                    properties: TransitStepPropertiesDTO(guidance: nil, type: "WALKING", distance: 88, time: 144, stops: nil, vehicles: nil),
                    path: nil
                ),
            ]
        )

        let route = RoutingMapper.transitRoute(dto)

        #expect(route.kind == .busAndSubway)
        #expect(route.fare == 1_850)
        #expect(route.transfers == 1)
        #expect(route.legs.map(\.kind) == [.subway, .walk])
        // 일반·급행으로 같은 노선이 두 번 와도 한 번만 남긴다.
        #expect(route.legs[0].lineNames == ["수인분당선"])
        #expect(route.legs[0].stops == ["태평", "모란", "왕십리"])
        #expect(route.legs[0].points.first == GeoPoint(latitude: 37.4, longitude: 127.1))
        #expect(route.legs[1].guidance.isEmpty)
        #expect(route.legs[1].lineNames.isEmpty)
    }

    @Test(arguments: [
        ("SAME_POINT", DomainError.destinationTooClose),
        ("EQUAL_POINTS", .destinationTooClose),
        ("TOO_FAR_AWAY", .routeNotFound(reason: "TOO_FAR_AWAY")),
        ("NO_RESULTS", .routeNotFound(reason: "NO_RESULTS")),
    ])
    func mapsFailureStatus(status: String, expected: DomainError) {
        #expect(RoutingMapper.error(forStatus: status) == expected)
    }
}

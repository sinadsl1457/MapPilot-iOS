import Testing
@testable import MapPilot

struct RouteMapperTests {
    private let origin = GeoPoint(latitude: 37.0, longitude: 127.0)
    private let destination = GeoPoint(latitude: 38.0, longitude: 128.0)

    @Test func vertexesAreLongitudeThenLatitude() {
        let points = RouteMapper.points(fromVertexes: [126.1, 37.1, 126.2, 37.2])

        #expect(points == [
            GeoPoint(latitude: 37.1, longitude: 126.1),
            GeoPoint(latitude: 37.2, longitude: 126.2),
        ])
    }

    @Test(arguments: [[], [126.1], [126.1, 37.1, 126.2]])
    func dropsUnpairedTrailingValue(vertexes: [Double]) {
        let points = RouteMapper.points(fromVertexes: vertexes)
        #expect(points.count == vertexes.count / 2)
    }

    @Test func wrapsRoadPointsWithOriginAndDestination() throws {
        let dto = RouteDTO(
            resultCode: 0,
            resultMsg: "길찾기 성공",
            summary: RouteSummaryDTO(distance: 1_500, duration: 300, fare: CarFareDTO(taxi: 5_600, toll: 1_200)),
            sections: [
                RouteSectionDTO(roads: [RoadDTO(vertexes: [127.1, 37.1]), RoadDTO(vertexes: [127.2, 37.2])]),
                RouteSectionDTO(roads: [RoadDTO(vertexes: [127.3, 37.3])]),
            ]
        )

        let route = try #require(RouteMapper.map(dto, origin: origin, destination: destination))

        #expect(route.points == [
            origin,
            GeoPoint(latitude: 37.1, longitude: 127.1),
            GeoPoint(latitude: 37.2, longitude: 127.2),
            GeoPoint(latitude: 37.3, longitude: 127.3),
            destination,
        ])
        #expect(route.distanceMeters == 1_500)
        #expect(route.durationSeconds == 300)
        #expect(route.taxiFare == 5_600)
        #expect(route.tollFare == 1_200)
    }

    @Test func missingSummaryIsNil() {
        let dto = RouteDTO(resultCode: 0, resultMsg: "", summary: nil, sections: nil)
        #expect(RouteMapper.map(dto, origin: origin, destination: destination) == nil)
    }
}

import Testing
@testable import SimpleTrackingiOS

/// Flutter subway_line_colors_test와 같은 경우.
@MainActor
struct SubwayLineColorsTests {
    private func leg(_ kind: TransitLeg.Kind, _ lines: [String]) -> TransitLeg {
        TransitLeg(kind: kind, durationSeconds: 600, distanceMeters: 1_000, guidance: "", lineNames: lines, stops: [],
                   points: [GeoPoint(latitude: 37.5, longitude: 127), GeoPoint(latitude: 37.51, longitude: 127.01)])
    }

    @Test(arguments: [
        ("1호선", UInt32(0x0052A4)),
        ("2호선", 0x00A84D),
        ("수도권 1호선", 0x0052A4),
        ("9호선", 0xBDB092),
        ("수인분당선", 0xF5A200),
        ("신분당선", 0xD4003B),
        ("경의중앙선", 0x77C4A3),
        ("인천 1호선", 0x7CA8D5), // 1호선 색이 아니어야 한다
    ])
    func lineNameToColor(name: String, rgb: UInt32) {
        #expect(SubwayLineColors.rgb(lineName: name) == rgb)
    }

    @Test func unknownLineIsNil() {
        #expect(SubwayLineColors.rgb(lineName: "부산 1호선 아님 노선") == nil)
        #expect(SubwayLineColors.rgb(lineName: "동해선") == nil)
    }

    @Test func onlySubwayLegsGetLineColor() {
        #expect(SubwayLineColors.rgb(of: leg(.subway, ["모르는선", "9호선"])) == 0xBDB092)
        #expect(SubwayLineColors.rgb(of: leg(.subway, ["모르는선"])) == nil)
        #expect(SubwayLineColors.rgb(of: leg(.bus, ["2"])) == nil)
    }

    @Test func mapLineCarriesLineColorOnlyForSubway() async throws {
        let subway = leg(.subway, ["9호선"])
        let bus = leg(.bus, ["146"])
        let route = Fixtures.transitRoute(minutes: 30, legs: [bus, subway])
        let repository = FakeRouteRepository(transit: .success([route]))
        let viewModel = RouteViewModel(
            findCarRoute: FindRouteUseCase(repository: repository),
            findWalkingRoute: FindWalkingRouteUseCase(repository: repository),
            findTransitRoutes: FindTransitRoutesUseCase(repository: repository)
        )
        await viewModel.start(to: Fixtures.place(id: "d", latitude: 37.6, longitude: 127.1), myLocation: Fixtures.cityHall)
        viewModel.showRoute(at: 0)

        let lines = try #require(viewModel.overlay?.lines)
        #expect(lines.first { $0.kind == .subway }?.rgb == 0xBDB092)
        #expect(lines.first { $0.kind == .bus }?.rgb == nil)
    }
}

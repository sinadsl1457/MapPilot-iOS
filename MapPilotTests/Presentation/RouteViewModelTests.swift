import Testing
@testable import MapPilot

/// Flutter route_notifier_test와 같은 경우를 확인한다.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RouteViewModelTests {
    private let destination = Fixtures.place(id: "dest", latitude: Fixtures.gangnamStation.latitude, longitude: Fixtures.gangnamStation.longitude)
    private let otherPlace = Fixtures.place(id: "other", latitude: 37.55, longitude: 127.05)
    private let carRoute = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 9_120, durationSeconds: 1_500)
    private let walkRoute = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 8_900, durationSeconds: 8_000)
    private let stationA = GeoPoint(latitude: 37.56, longitude: 126.98)
    private let stationB = GeoPoint(latitude: 37.50, longitude: 127.02)

    private var transitRoutes: [TransitRoute] {
        [
            Fixtures.transitRoute(minutes: 40, legs: [
                TransitLeg(kind: .subway, durationSeconds: 2_000, distanceMeters: 8_000, guidance: "2호선", lineNames: ["2호선"], stops: ["시청", "강남"], points: [stationA, stationB]),
            ]),
            Fixtures.transitRoute(minutes: 50),
        ]
    }

    private func makeViewModel(_ repository: FakeRouteRepository) -> RouteViewModel {
        RouteViewModel(
            findCarRoute: FindRouteUseCase(repository: repository),
            findWalkingRoute: FindWalkingRouteUseCase(repository: repository),
            findTransitRoutes: FindTransitRoutesUseCase(repository: repository)
        )
    }

    private func defaultRepository(delay: Duration? = nil) -> FakeRouteRepository {
        FakeRouteRepository(result: carRoute, walk: .success(walkRoute), transit: .success(transitRoutes), delay: delay)
    }

    // MARK: - 시작

    @Test func startFetchesAllModes() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)

        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        #expect(viewModel.isActive)
        #expect(viewModel.origin == .myLocation)
        #expect(viewModel.destination == .place(destination))
        #expect(viewModel.results[.car] == .route(carRoute))
        #expect(viewModel.results[.walk] == .route(walkRoute))
        #expect(viewModel.results[.transit] == .transit(transitRoutes))
        #expect(await repository.callCount == 1)
        #expect(await repository.walkCallCount == 1)
        #expect(await repository.transitCallCount == 1)
    }

    @Test func startsInListStageWithTransitAndNoLine() async {
        let viewModel = makeViewModel(defaultRepository())

        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        #expect(viewModel.selectedMode == .transit)
        #expect(viewModel.isShowingRoute == false)
        #expect(viewModel.isShowingList)
        #expect(viewModel.overlay == nil)
    }

    @Test func pickingFromListDrawsThatRouteAndFitsCamera() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        var effects = viewModel.effects.makeAsyncIterator()

        viewModel.showRoute(at: 1)

        #expect(viewModel.isShowingRoute)
        #expect(viewModel.isShowingList == false)
        #expect(viewModel.selectedTransitRoute == transitRoutes[1])
        #expect(await effects.next() == .fitCamera(viewModel.overlay?.allPoints ?? []))
    }

    @Test func backToListClearsLineButKeepsResults() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        viewModel.showRoute(at: 0)

        viewModel.backToList()

        #expect(viewModel.isShowingRoute == false)
        #expect(viewModel.overlay == nil)
        #expect(viewModel.results[.transit] == .transit(transitRoutes))
    }

    @Test func searchingAgainWhileShowingRouteGoesBackToList() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        viewModel.showRoute(at: 0)

        await viewModel.swap(myLocation: Fixtures.cityHall)

        #expect(viewModel.isShowingRoute == false)
        #expect(viewModel.selectedTransitIndex == 0)
    }

    @Test func transitOverlayConnectsOriginAndDestinationWithWalkLines() async throws {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        viewModel.showRoute(at: 0)

        let overlay = try #require(viewModel.overlay)
        #expect(overlay.lines.map(\.kind) == [.walk, .subway, .walk])
        #expect(overlay.lines.first?.points == [Fixtures.cityHall, stationA])
        #expect(overlay.lines.last?.points == [stationB, Fixtures.gangnamStation])
        #expect(overlay.start == Fixtures.cityHall)
        #expect(overlay.end == Fixtures.gangnamStation)
    }

    // MARK: - 자동차·도보는 바로 지도에

    @Test func walkTabDrawsDirectlyAndFitsCamera() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        var effects = viewModel.effects.makeAsyncIterator()

        viewModel.selectMode(.walk)

        #expect(viewModel.isShowingRoute)
        #expect(viewModel.overlay?.lines == [RouteLine(kind: .walk, points: walkRoute.points)])
        #expect(await effects.next() == .fitCamera(viewModel.overlay?.allPoints ?? []))
    }

    @Test func carModeDrawsAsResultsArriveWithoutList() async {
        let viewModel = makeViewModel(defaultRepository())
        viewModel.selectMode(.car)
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        #expect(viewModel.isShowingRoute)
        #expect(viewModel.isShowingList == false)
        #expect(await effects.next() == .fitCamera(viewModel.overlay?.allPoints ?? []))
    }

    @Test func transitTabWhileWalkingGoesBackToList() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        viewModel.selectMode(.walk)

        viewModel.selectMode(.transit)

        #expect(viewModel.isShowingRoute == false)
        #expect(viewModel.isShowingList)
    }

    // MARK: - 실패·안내

    @Test func oneModeFailingKeepsOthers() async {
        let repository = FakeRouteRepository(result: carRoute, walk: .failure(.routeNotFound(reason: "TOO_FAR_AWAY")), transit: .success(transitRoutes))
        let viewModel = makeViewModel(repository)

        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        #expect(viewModel.isActive)
        #expect(viewModel.results[.walk] == .failed(.routeNotFound(reason: "TOO_FAR_AWAY")))
        #expect(viewModel.results[.car] == .route(carRoute))
        viewModel.selectMode(.walk)
        #expect(viewModel.overlay == nil)
    }

    @Test func withoutMyLocationShowsMessageAndDoesNotCallApi() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, myLocation: nil)

        #expect(viewModel.isActive == false)
        guard case .showMessage = await effects.next() else {
            Issue.record("showMessage를 기대함")
            return
        }
        #expect(await repository.callCount == 0)
    }

    @Test func tooCloseDoesNotOpenRouteMode() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()
        let nearby = Fixtures.place(id: "near", latitude: Fixtures.cityHall.latitude, longitude: Fixtures.cityHall.longitude)

        await viewModel.start(to: nearby, myLocation: Fixtures.cityHall)

        #expect(viewModel.isActive == false)
        #expect(await effects.next() == .showError(.destinationTooClose))
        #expect(await repository.callCount == 0)
        #expect(await repository.transitCallCount == 0)
    }

    @Test func closeClearsStateButKeepsSelectedMode() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        viewModel.selectMode(.car)

        viewModel.close()

        #expect(viewModel.isActive == false)
        #expect(viewModel.isShowingList == false)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.overlay == nil)
        #expect(viewModel.selectedMode == .car)
    }

    // MARK: - 출발지·도착지 바꾸기

    @Test func changingOriginToPlaceSearchesFromThatPlace() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        await viewModel.changeOrigin(.place(otherPlace), myLocation: Fixtures.cityHall)

        #expect(viewModel.origin == .place(otherPlace))
        #expect(viewModel.originPoint == otherPlace.location)
        #expect(await repository.carRequests.last?.origin == otherPlace.location)
    }

    @Test func swapMakesMyLocationTheDestination() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)

        await viewModel.swap(myLocation: Fixtures.cityHall)

        #expect(viewModel.origin == .place(destination))
        #expect(viewModel.destination == .myLocation)
        #expect(await repository.carRequests.last?.origin == destination.location)
        #expect(await repository.carRequests.last?.destination == Fixtures.cityHall)
    }

    @Test func swapWithoutMyLocationKeepsStateAndShowsMessage() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.swap(myLocation: nil)

        #expect(viewModel.origin == .myLocation)
        guard case .showMessage = await effects.next() else {
            Issue.record("showMessage를 기대함")
            return
        }
    }

    @Test func originTooCloseToDestinationIsRejected() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, myLocation: Fixtures.cityHall)
        var effects = viewModel.effects.makeAsyncIterator()
        let nextToDestination = Fixtures.place(id: "next", latitude: destination.location.latitude, longitude: destination.location.longitude)

        await viewModel.changeOrigin(.place(nextToDestination), myLocation: Fixtures.cityHall)

        #expect(viewModel.origin == .myLocation)
        #expect(await effects.next() == .showError(.destinationTooClose))
    }

    @Test func destinationCanBeMyLocation() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        await viewModel.plan(RoutePlan(origin: .place(otherPlace), destination: .place(destination), mode: .car), myLocation: Fixtures.cityHall)

        await viewModel.changeDestination(.myLocation, myLocation: Fixtures.cityHall)

        #expect(viewModel.destination == .myLocation)
        #expect(await repository.carRequests.last?.destination == Fixtures.cityHall)
    }

    // MARK: - 기타

    @Test func lateResponseAfterCloseIsDiscarded() async throws {
        let viewModel = makeViewModel(defaultRepository(delay: .milliseconds(200)))

        let search = Task { await viewModel.start(to: destination, myLocation: Fixtures.cityHall) }
        try await Task.sleep(for: .milliseconds(50))
        viewModel.close()
        await search.value

        #expect(viewModel.results.isEmpty)
    }

    @Test func planUsesPlannedModeAndEndpoints() async {
        let viewModel = makeViewModel(defaultRepository())

        await viewModel.plan(RoutePlan(origin: .place(otherPlace), destination: .place(destination), mode: .walk), myLocation: nil)

        #expect(viewModel.selectedMode == .walk)
        #expect(viewModel.origin == .place(otherPlace))
        #expect(viewModel.isShowingRoute)
    }
}

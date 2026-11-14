import Testing
@testable import SimpleTrackingiOS

@MainActor
struct KakaoMapStateTests {
    private let overlay = RouteOverlay(
        lines: [RouteLine(kind: .car, points: [Fixtures.cityHall, Fixtures.gangnamStation])],
        start: Fixtures.cityHall,
        end: Fixtures.gangnamStation
    )

    @Test func cameraCommandBeforeReadyRunsOnAttach() {
        let state = KakaoMapState()
        let map = FakeMap()

        state.moveCamera(to: Fixtures.cityHall, zoom: 15)
        state.moveCamera(to: Fixtures.gangnamStation, zoom: 17)
        #expect(map.cameraMoves.isEmpty)

        state.attach(map)

        // 준비 전에 쌓인 명령 중 마지막 것만 실행한다.
        #expect(map.cameraMoves.count == 1)
        #expect(map.cameraMoves.first?.point == Fixtures.gangnamStation)
        #expect(map.cameraMoves.first?.zoom == 17)
    }

    @Test func pendingCameraRunsOnlyOnce() {
        let state = KakaoMapState()
        state.moveCamera(to: Fixtures.cityHall, zoom: 15)
        let first = FakeMap()
        state.attach(first)
        state.detach()

        let second = FakeMap()
        state.attach(second)

        #expect(first.cameraMoves.count == 1)
        #expect(second.cameraMoves.isEmpty)
    }

    @Test func cameraCommandAfterReadyRunsImmediately() {
        let state = KakaoMapState()
        let map = FakeMap()
        state.attach(map)

        state.moveCamera(to: Fixtures.cityHall, zoom: 15)

        #expect(map.cameraMoves.count == 1)
    }

    @Test func locationBeforeReadyIsReplayedOnAttach() {
        let state = KakaoMapState()
        let location = Fixtures.location()
        state.updateMyLocation(location)

        let map = FakeMap()
        state.attach(map)

        #expect(map.locations == [location])
    }

    @Test func fitBeforeReadyRunsOnAttachAndReplacesEarlierMove() {
        let state = KakaoMapState()
        state.moveCamera(to: Fixtures.cityHall, zoom: 15)
        state.fitCamera(to: [Fixtures.cityHall, Fixtures.gangnamStation], insets: MapInsets(top: 100, bottom: 200))

        let map = FakeMap()
        state.attach(map)

        #expect(map.cameraMoves.isEmpty)
        #expect(map.fits == [[Fixtures.cityHall, Fixtures.gangnamStation]])
    }

    @Test func fitWithNoPointsIsIgnored() {
        let state = KakaoMapState()
        let map = FakeMap()
        state.attach(map)

        state.fitCamera(to: [], insets: MapInsets(top: 100, bottom: 200))

        #expect(map.fits.isEmpty)
    }

    @Test func markersBeforeReadyAreReplayedOnAttach() {
        let state = KakaoMapState()
        let markers = [PlaceMarker(id: "a", point: Fixtures.cityHall, number: 1)]
        state.showPlaceMarkers(markers, selectedID: "a")

        let map = FakeMap()
        state.attach(map)

        #expect(map.markerUpdates.last?.markers == markers)
        #expect(map.markerUpdates.last?.selectedID == "a")
    }

    @Test func markerTapIsForwarded() {
        let state = KakaoMapState()
        var tapped: [String] = []
        state.onPlaceTapped = { tapped.append($0) }

        state.placeMarkerTapped(id: "a")

        #expect(tapped == ["a"])
    }

    @Test func routeBeforeReadyIsReplayedOnAttach() {
        let state = KakaoMapState()
        state.showRoute(overlay)

        let map = FakeMap()
        state.attach(map)

        #expect(map.routes.last == overlay)
    }

    @Test func clearedRouteIsNotReplayed() {
        let state = KakaoMapState()
        state.showRoute(overlay)
        state.showRoute(nil)

        let map = FakeMap()
        state.attach(map)

        #expect(map.routes.last == .some(nil))
    }

    @Test func nonAnimatedMoveBeforeReadyKeepsFlag() {
        let state = KakaoMapState()
        state.moveCamera(to: Fixtures.cityHall, zoom: 17, animated: false)

        let map = FakeMap()
        state.attach(map)

        #expect(map.cameraMoves.first?.animated == false)
    }

    @Test func followModeBeforeReadyIsReplayedOnAttach() {
        let state = KakaoMapState()
        state.setFollowMode(.followWithHeading)

        let map = FakeMap()
        state.attach(map)

        #expect(map.followModes.last == .followWithHeading)
    }

    @Test func userGestureIsForwarded() {
        let state = KakaoMapState()
        var gestures: [MapGesture] = []
        state.onUserGesture = { gestures.append($0) }

        state.userDidGesture(.pan)
        state.userDidGesture(.rotate)

        #expect(gestures == [.pan, .rotate])
    }

    @Test func attachClearsPreviousFailure() {
        let state = KakaoMapState()
        state.fail("인증 실패")
        #expect(state.loadFailure == "인증 실패")

        let map = FakeMap() // state는 지도를 weak로 잡으므로 테스트가 붙잡고 있어야 한다.
        state.attach(map)

        #expect(state.loadFailure == nil)
        #expect(state.isMapReady)
    }
}

@MainActor
private final class FakeMap: KakaoMapCommands {
    var cameraMoves: [(point: GeoPoint, zoom: Int, animated: Bool)] = []
    var followModes: [FollowMode] = []
    var fits: [[GeoPoint]] = []
    var locations: [UserLocation?] = []
    var markerUpdates: [(markers: [PlaceMarker], selectedID: String?)] = []

    func moveCamera(to point: GeoPoint, zoom: Int, animated: Bool) {
        cameraMoves.append((point, zoom, animated))
    }

    func setFollowMode(_ mode: FollowMode) {
        followModes.append(mode)
    }

    func fitCamera(to points: [GeoPoint], insets: MapInsets) {
        fits.append(points)
    }

    func showPlaceMarkers(_ markers: [PlaceMarker], selectedID: String?) {
        markerUpdates.append((markers, selectedID))
    }

    var routes: [RouteOverlay?] = []

    func showRoute(_ overlay: RouteOverlay?) {
        routes.append(overlay)
    }

    func updateMyLocation(_ location: UserLocation?) {
        locations.append(location)
    }
}

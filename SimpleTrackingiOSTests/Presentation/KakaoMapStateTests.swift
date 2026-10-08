import Testing
@testable import SimpleTrackingiOS

@MainActor
struct KakaoMapStateTests {
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
    var cameraMoves: [(point: GeoPoint, zoom: Int)] = []
    var locations: [UserLocation?] = []

    func moveCamera(to point: GeoPoint, zoom: Int) {
        cameraMoves.append((point, zoom))
    }

    func updateMyLocation(_ location: UserLocation?) {
        locations.append(location)
    }
}

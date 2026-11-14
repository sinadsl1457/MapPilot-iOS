import Testing
@testable import SimpleTrackingiOS

/// 기대한 효과가 나오지 않으면 `effects.next()`가 끝없이 기다리므로 시간 제한을 둔다.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelTests {
    private func makeViewModel(_ repository: FakeLocationRepository) -> MapViewModel {
        MapViewModel(
            observeLocation: ObserveLocationUseCase(repository: repository),
            getLocationPermission: GetLocationPermissionUseCase(repository: repository),
            requestLocationPermission: RequestLocationPermissionUseCase(repository: repository)
        )
    }

    // MARK: - 내 위치 버튼

    @Test func tapWithoutPermissionRequestsPermission() async {
        let viewModel = makeViewModel(FakeLocationRepository(permission: .notDetermined))
        var effects = viewModel.effects.makeAsyncIterator()

        viewModel.onMyLocationButtonTapped()

        #expect(await effects.next() == .requestLocationPermission)
    }

    @Test func tapWithoutLocationShowsMessage() async {
        let viewModel = makeViewModel(FakeLocationRepository(permission: .authorized, keepsStreamOpen: true))
        var effects = viewModel.effects.makeAsyncIterator()
        await viewModel.onAppear()

        viewModel.onMyLocationButtonTapped()

        guard case .showMessage = await effects.next() else {
            Issue.record("showMessage를 기대함")
            return
        }
        #expect(viewModel.myLocation == nil)
    }

    @Test func tapWithLocationMovesCamera() async {
        let first = Fixtures.location(latitude: 37.1)
        let latest = Fixtures.location(latitude: 37.2)
        let viewModel = makeViewModel(FakeLocationRepository(updates: [first, latest]))
        var effects = viewModel.effects.makeAsyncIterator()
        await viewModel.onAppear()
        await viewModel.waitForLocationUpdates()

        viewModel.onMyLocationButtonTapped()

        #expect(await effects.next() == .moveCamera(first.point, zoom: MapViewModel.myLocationZoom))
        #expect(await effects.next() == .moveCamera(latest.point, zoom: MapViewModel.myLocationZoom))
    }

    // MARK: - 따라가기 (Flutter map_notifier_test와 같은 경우)

    /// 첫 위치를 받아 카메라가 내 위치에 있는 상태.
    private func viewModelOnMyLocation() async -> MapViewModel {
        let viewModel = makeViewModel(FakeLocationRepository(updates: [Fixtures.location()]))
        await viewModel.onAppear()
        await viewModel.waitForLocationUpdates()
        return viewModel
    }

    private func following(_ mode: FollowMode) async -> MapViewModel {
        let viewModel = await viewModelOnMyLocation()
        while viewModel.followMode != mode { viewModel.onMyLocationButtonTapped() }
        return viewModel
    }

    @Test func tapsCycleFollowRotateOff() async {
        let viewModel = await viewModelOnMyLocation()
        var modes: [FollowMode] = []

        for _ in 0..<4 {
            viewModel.onMyLocationButtonTapped()
            modes.append(viewModel.followMode)
        }

        #expect(modes == [.follow, .followWithHeading, .none, .follow])
    }

    @Test func afterPanFirstTapOnlyMovesCamera() async {
        let viewModel = await viewModelOnMyLocation()
        viewModel.onMapPanned()
        #expect(viewModel.isCameraOnMyLocation == false)

        viewModel.onMyLocationButtonTapped()
        #expect(viewModel.followMode == .none)
        #expect(viewModel.isCameraOnMyLocation)

        viewModel.onMyLocationButtonTapped()
        #expect(viewModel.followMode == .follow)
    }

    @Test func afterOtherFeatureMovesCameraFirstTapOnlyMovesCamera() async {
        let viewModel = await following(.follow)

        viewModel.stopFollowing()
        viewModel.onMyLocationButtonTapped()

        #expect(viewModel.followMode == .none)
        #expect(viewModel.isCameraOnMyLocation)
    }

    @Test func doesNotFollowWithoutLocation() async {
        let viewModel = makeViewModel(FakeLocationRepository(permission: .authorized, keepsStreamOpen: true))
        await viewModel.onAppear()

        viewModel.onMyLocationButtonTapped()
        viewModel.onMyLocationButtonTapped()

        #expect(viewModel.followMode == .none)
    }

    @Test func panStopsFollowing() async {
        let viewModel = await following(.followWithHeading)

        viewModel.onMapPanned()

        #expect(viewModel.followMode == .none)
        #expect(viewModel.isCameraOnMyLocation == false)
    }

    @Test func rotateKeepsFollowingButStopsRotation() async {
        let viewModel = await following(.followWithHeading)

        viewModel.onMapRotated()

        #expect(viewModel.followMode == .follow)
    }

    @Test func rotateWhileOnlyFollowingKeepsMode() async {
        let viewModel = await following(.follow)

        viewModel.onMapRotated()

        #expect(viewModel.followMode == .follow)
    }

    @Test func losingPermissionStopsFollowing() async {
        let viewModel = makeViewModel(FakeLocationRepository(
            updates: [Fixtures.location()],
            failure: DomainError.locationPermissionDenied
        ))
        await viewModel.onAppear()
        // 스트림이 끝나기 전에 따라가기를 켤 수 없어, 오류 뒤 상태만 확인한다.
        await viewModel.waitForLocationUpdates()

        #expect(viewModel.followMode == .none)
        #expect(viewModel.isCameraOnMyLocation == false)
    }

    // MARK: - 위치 스트림

    @Test func movesCameraOnlyOnFirstLocation() async {
        let locations = (1...3).map { Fixtures.location(latitude: 37 + Double($0) / 10) }
        let viewModel = makeViewModel(FakeLocationRepository(lastKnown: locations[0], updates: Array(locations.dropFirst())))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.onAppear()
        await viewModel.waitForLocationUpdates()
        // 두 번째·세 번째 위치가 moveCamera를 냈다면 아래 탭보다 먼저 나온다.
        viewModel.onMyLocationButtonTapped()

        #expect(await effects.next() == .moveCamera(locations[0].point, zoom: MapViewModel.myLocationZoom))
        #expect(await effects.next() == .moveCamera(locations[2].point, zoom: MapViewModel.myLocationZoom))
        #expect(viewModel.myLocation == locations[2])
    }

    @Test func streamErrorRevokesPermissionAndShowsError() async {
        let viewModel = makeViewModel(FakeLocationRepository(
            updates: [Fixtures.location()],
            failure: DomainError.locationPermissionDenied
        ))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.onAppear()
        await viewModel.waitForLocationUpdates()

        #expect(await effects.next() == .moveCamera(Fixtures.cityHall, zoom: MapViewModel.myLocationZoom))
        #expect(await effects.next() == .showError(.locationPermissionDenied))
        #expect(viewModel.hasLocationPermission == false)
        #expect(viewModel.myLocation == nil)
    }

    @Test func unexpectedStreamErrorBecomesUnknown() async {
        struct Boom: Error {}
        let viewModel = makeViewModel(FakeLocationRepository(failure: Boom()))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.onAppear()
        await viewModel.waitForLocationUpdates()

        #expect(await effects.next() == .showError(.unknown))
    }

    // MARK: - 권한

    @Test func appearWithUndeterminedPermissionRequestsIt() async {
        let viewModel = makeViewModel(FakeLocationRepository(permission: .notDetermined))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.onAppear()

        #expect(await effects.next() == .requestLocationPermission)
        #expect(viewModel.hasLocationPermission == false)
    }

    @Test func appearWithDeniedPermissionStaysQuiet() async {
        let repository = FakeLocationRepository(permission: .denied)
        let viewModel = makeViewModel(repository)

        await viewModel.onAppear()

        #expect(viewModel.hasLocationPermission == false)
        #expect(viewModel.isSettingsAlertPresented == false)
        #expect(await repository.requestPermissionCount == 0)
    }

    @Test func grantingPermissionStartsObserving() async {
        let location = Fixtures.location()
        let repository = FakeLocationRepository(
            permission: .notDetermined,
            permissionAfterRequest: .authorized,
            updates: [location]
        )
        let viewModel = makeViewModel(repository)

        await viewModel.requestLocationPermission()
        await viewModel.waitForLocationUpdates()

        #expect(await repository.requestPermissionCount == 1)
        #expect(viewModel.hasLocationPermission)
        #expect(viewModel.myLocation == location)
    }

    @Test func requestWhenAlreadyDeniedShowsSettingsAlert() async {
        let repository = FakeLocationRepository(permission: .denied)
        let viewModel = makeViewModel(repository)

        await viewModel.requestLocationPermission()

        #expect(viewModel.isSettingsAlertPresented)
        #expect(await repository.requestPermissionCount == 0)
    }

    @Test func denyingInPromptDoesNotShowSettingsAlert() async {
        let viewModel = makeViewModel(FakeLocationRepository(permission: .notDetermined, permissionAfterRequest: .denied))

        await viewModel.requestLocationPermission()

        #expect(viewModel.hasLocationPermission == false)
        #expect(viewModel.isSettingsAlertPresented == false)
    }
}

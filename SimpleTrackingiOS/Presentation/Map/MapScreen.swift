import SwiftUI

/// 지도 화면 = 앱의 메인 화면. 내 위치·검색·길찾기 ViewModel을 지도와 UI에 연결한다.
/// 지도 반영 통로: 상태 변화는 onChange, 일회성 이벤트는 effects 스트림.
/// 길찾기 흐름: 길찾기 버튼 → 준비 화면(RoutePlannerPage) → 경로 목록(RouteListPage, 대중교통) → 고른 경로를 지도에.
/// 자동차·도보는 목록 없이 바로 지도에 그린다.
struct MapScreen: View {
    let kakaoNativeAppKey: String
    let viewModel: MapViewModel
    let search: PlaceSearchViewModel
    let route: RouteViewModel
    /// 길찾기 준비 화면이 열릴 때마다 새로 만든다. 인자는 지난 길찾기에서 고른 이동 수단.
    let makeRoutePlanner: (TravelMode) -> RoutePlannerViewModel
    /// 출발지·도착지 선택 페이지가 열릴 때마다 새로 만든다.
    let makeEndpointSearch: () -> EndpointSearchViewModel

    @State private var mapState = KakaoMapState()
    @State private var toastMessage: String?
    @State private var sheetDetent: BottomSheetDetent = .medium
    @State private var sheetHeight: CGFloat = 0
    @State private var routeCardHeight: CGFloat = 0
    /// 상단 UI(검색창·칩 또는 길찾기 카드·탭)의 높이. 카메라를 맞출 때 위쪽 여백이 된다.
    @State private var topControlsHeight: CGFloat = 0
    /// 화면 높이와 위·아래 안전 영역. 카메라 여백 계산에 쓴다(지도는 안전 영역까지 덮는다).
    @State private var screen = ScreenMetrics()
    @State private var isPlannerPresented = false
    /// 준비 화면에서 정한 길찾기. 준비 화면이 다 닫힌 뒤 찾는다(닫히는 중에 목록을 띄우면 무시될 수 있다).
    @State private var pendingPlan: RoutePlan?
    /// 자동차·도보 경로를 보는 중 출발지·도착지 줄을 눌러 여는 선택 페이지.
    @State private var pickingOnMap: EndpointRole?
    /// 길찾기를 시작하기 직전의 카메라. 길찾기가 끝나면 여기로 돌아간다.
    @State private var cameraBeforeRoute: (center: GeoPoint, zoom: Int)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var isSheetVisible: Bool { search.source != nil && !route.isActive }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if kakaoNativeAppKey.isEmpty {
                missingKeyNotice
            } else {
                content
            }
        }
        .alert("permission.alert.title", isPresented: $viewModel.isSettingsAlertPresented) {
            Button("permission.alert.openSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("permission.alert.message")
        }
        .fullScreenCover(item: $pickingOnMap) { role in
            EndpointPickerPage(
                viewModel: makeEndpointSearch(),
                title: role.title,
                myLocation: myLocation,
                onPick: { endpoint in
                    pickingOnMap = nil
                    Task {
                        switch role {
                        case .origin: await route.changeOrigin(endpoint, myLocation: myLocation)
                        case .destination: await route.changeDestination(endpoint, myLocation: myLocation)
                        }
                    }
                },
                onBack: { pickingOnMap = nil }
            )
        }
        .task { await viewModel.onAppear() }
        .task { await search.onAppear() }
        .task { await consumeMapEffects() }
        .task { await consumeSearchEffects() }
        .task { await consumeRouteEffects() }
        .onAppear {
            mapState.onPlaceTapped = { [search] id in search.selectPlace(id: id) }
            mapState.onUserGesture = { [viewModel] gesture in
                switch gesture {
                case .pan: viewModel.onMapPanned()
                case .rotate: viewModel.onMapRotated()
                }
            }
        }
        .onChange(of: viewModel.myLocation) { _, location in
            mapState.updateMyLocation(location)
        }
        // 따라가기 모드를 지도에 알린다. 카메라 추적은 SDK 트래킹이 한다.
        .onChange(of: viewModel.followMode) { _, mode in
            mapState.setFollowMode(mode)
        }
        .onChange(of: search.places) { syncPlaceMarkers() }
        .onChange(of: route.isActive) { _, isActive in
            // 경로에 맞춰 줌 아웃하기 전에 지금 카메라를 기억해 두고, 길찾기가 끝나면 되돌린다.
            if isActive {
                cameraBeforeRoute = zip(mapState.cameraCenter, mapState.cameraZoom).map { (center: $0, zoom: $1) }
            } else {
                restoreCameraAfterRoute()
            }
            syncPlaceMarkers()
        }
        // 목록에서 경로를 고르거나 목록으로 돌아가면 지도 선을 다시 그린다(목록 단계는 선 없음).
        .onChange(of: route.overlay) { _, overlay in
            mapState.showRoute(overlay)
        }
        .onChange(of: search.selectedPlace) { _, place in
            syncPlaceMarkers()
            withAnimation(.spring(duration: 0.3)) {
                sheetDetent = place == nil ? .medium : .collapsed
            }
        }
        .onChange(of: search.source) { _, source in
            if source != nil {
                withAnimation(.spring(duration: 0.3)) { sheetDetent = .medium }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await viewModel.onBecameActive() }
            case .background: viewModel.onEnteredBackground()
            default: break
            }
        }
    }

    // MARK: - 화면 구성

    /// 아래에서 위 순서: 지도 → 로드 실패 안내 → 상단(검색창·칩 또는 길찾기 카드·탭)
    /// → 하단(장소 시트 / 고른 경로 카드) → 내 위치 버튼 → 토스트 → 검색 페이지.
    /// 준비 화면·경로 목록은 이 화면 위에 덮이는 전체 화면이다.
    private var content: some View {
        GeometryReader { geometry in
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            // 내 위치 버튼·토스트를 붙일 높이: 시트 윗변 위 → 경로 카드 위 → 화면 아래.
            // 시트 위치는 중간 높이까지만 따른다. 시트를 끝까지 올리면 버튼은 숨기는데, 높이를 그대로 따르면
            // 버튼 자리가 화면보다 커져 화면 전체가 늘어나고 → 시트가 더 높게 재고 → … 끝없이 커져 지도가 죽는다.
            let floatingBottom = if isSheetVisible {
                min(sheetHeight, mediumSheetHeight) + 12
            } else if route.isShowingRoute {
                routeCardHeight + bottomSafeArea + 12
            } else {
                bottomSafeArea + 24
            }

            ZStack(alignment: .top) {
                KakaoMapView(appKey: kakaoNativeAppKey, state: mapState, isActive: scenePhase == .active)
                    .ignoresSafeArea()

                if let failure = mapState.loadFailure {
                    Text("map.loadFailed \(failure)")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                }

                topControls
                    .padding(.top, 8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topControlsHeight = $0 }

                if isSheetVisible {
                    BottomSheet(detent: $sheetDetent, visibleHeight: $sheetHeight) {
                        PlaceResultsHeader(viewModel: search)
                    } content: {
                        PlaceResultsContent(viewModel: search, myLocation: myLocation, onRoute: startRoute)
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                }

                if route.isShowingRoute {
                    RouteSummaryCard(mode: route.selectedMode, result: route.selectedResult, transitIndex: route.selectedTransitIndex)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { routeCardHeight = $0 }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom))
                }

                MyLocationButton(
                    hasPermission: viewModel.hasLocationPermission,
                    followMode: viewModel.followMode,
                    isCameraOnMyLocation: viewModel.isCameraOnMyLocation
                ) {
                    viewModel.onMyLocationButtonTapped()
                }
                // 시트를 중간보다 높이 올리면 목록을 보는 중이라 숨긴다(버튼이 화면 위로 밀려 올라가지 않게).
                .opacity(isSheetVisible && sheetHeight > mediumSheetHeight + 1 ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: isSheetVisible && sheetHeight > mediumSheetHeight + 1)
                .padding(.trailing, 16)
                .padding(.bottom, floatingBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea(edges: .bottom)
            }
            .onGeometryChange(for: ScreenMetrics.self) { proxy in
                ScreenMetrics(height: proxy.size.height, safeTop: proxy.safeAreaInsets.top, safeBottom: proxy.safeAreaInsets.bottom)
            } action: { screen = $0 }
            .toast(message: $toastMessage, bottomInset: floatingBottom + 60 - bottomSafeArea)
            .animation(.spring(duration: 0.3), value: isSheetVisible)
            .animation(.spring(duration: 0.3), value: route.isShowingRoute)
            .animation(.spring(duration: 0.3), value: route.selectedMode)
            .overlay {
                if search.isSearchPagePresented {
                    SearchPage(viewModel: search, center: myLocation)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: search.isSearchPagePresented)
            // 대중교통 경로 목록. 길찾기 중이고 지도에 경로를 보이지 않는 동안 덮는다.
            // 경로를 고르면(isShowingRoute) 닫히고, ✕면 길찾기가 끝나(isActive 꺼짐) 닫힌다.
            .fullScreenCover(isPresented: Binding(get: { route.isShowingList }, set: { _ in })) {
                RouteListPage(route: route, myLocation: myLocation, makeEndpointSearch: makeEndpointSearch)
            }
        }
        .fullScreenCover(isPresented: $isPlannerPresented, onDismiss: runPendingPlan) {
            RoutePlannerPage(
                viewModel: makeRoutePlanner(route.selectedMode),
                myLocation: myLocation,
                makeEndpointSearch: makeEndpointSearch,
                onComplete: { plan in
                    pendingPlan = plan
                    isPlannerPresented = false
                },
                onClose: { isPlannerPresented = false }
            )
        }
    }

    /// 길찾기 중이 아니면 검색창·길찾기 버튼·칩, 자동차·도보 경로를 보는 중이면 출발·도착 카드와 이동 수단 탭,
    /// 대중교통 경로를 보는 중이면 ‹ + "출발 → 도착".
    @ViewBuilder
    private var topControls: some View {
        if route.isShowingRoute, route.selectedMode == .transit {
            RouteShownBar(
                originName: route.origin?.title ?? "",
                destinationName: route.destination?.title ?? "",
                onBack: route.backToList
            )
            .padding(.horizontal, 16)
        } else if route.isShowingRoute {
            VStack(spacing: 8) {
                RouteHeader(
                    originName: route.origin?.title,
                    destinationName: route.destination?.title,
                    onTapOrigin: { pickingOnMap = .origin },
                    onTapDestination: { pickingOnMap = .destination },
                    onSwap: { Task { await route.swap(myLocation: myLocation) } },
                    onClose: route.close
                )
                // 대중교통 탭을 누르면 목록으로 간다.
                TravelModeTabs(selected: route.selectedMode, results: route.results) { mode in
                    withAnimation(.spring(duration: 0.3)) { route.selectMode(mode) }
                }
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    MapSearchBar(
                        keyword: search.keyword,
                        showsClear: isSheetVisible,
                        onTap: search.openSearchPage,
                        onClear: search.clearResults
                    )
                    DirectionsButton { isPlannerPresented = true }
                }
                .padding(.horizontal, 16)

                CategoryChips(selected: search.selectedCategory) { category in
                    Task { await search.toggleCategory(category, around: searchCenter) }
                }
            }
        }
    }

    private var missingKeyNotice: some View {
        ContentUnavailableView(
            "map.missingKey.title",
            systemImage: "key.slash",
            description: Text("map.missingKey.description")
        )
    }

    private var myLocation: GeoPoint? { viewModel.myLocation?.point }

    /// 카테고리 검색 기준: 지금 보고 있는 지도 중심 → 내 위치 → 기본 위치.
    private var searchCenter: GeoPoint {
        mapState.cameraCenter ?? myLocation ?? KakaoMapController.defaultCenter
    }

    // MARK: - 길찾기

    /// 장소 상세의 "길찾기". 내 위치에서 그 장소까지 찾는다(대중교통이면 목록이 뜬다).
    private func startRoute(to place: Place) {
        // 권한이 없으면 길찾기 대신 권한부터 요청한다.
        guard viewModel.hasLocationPermission else {
            viewModel.onMyLocationButtonTapped()
            return
        }
        Task { await route.start(to: place, myLocation: myLocation) }
    }

    /// 준비 화면이 다 닫힌 뒤 정한 길찾기를 시작한다.
    private func runPendingPlan() {
        guard let plan = pendingPlan else { return }
        pendingPlan = nil
        Task { await route.plan(plan, myLocation: myLocation) }
    }

    /// 길찾기가 끝나면 카메라를 길찾기 시작 전 위치·줌으로 돌려준다(경로 전체를 보려고 줌 아웃한 채 남지 않게).
    /// 길찾기 중에 따라가기를 켰더라도 끈다. 켜 두면 복원한 카메라를 트래킹이 다시 끌고 간다.
    private func restoreCameraAfterRoute() {
        mapState.showRoute(nil)
        let before = cameraBeforeRoute
        cameraBeforeRoute = nil
        if let before {
            cameraAwayFromMe { mapState.moveCamera(to: before.center, zoom: before.zoom) }
        } else if let place = search.selectedPlace {
            cameraAwayFromMe { mapState.moveCamera(to: place.location, zoom: 17) }
        }
    }

    // MARK: - 지도 명령

    /// [points]가 위 UI와 아래 UI([bottomCovered]) 사이, 실제로 보이는 곳에 들어오게 맞춘다.
    /// 아래 시트는 펼쳐지는 중일 수 있어 지금 높이가 아니라 멈출 높이를 넘겨받는다.
    private func fitCamera(to points: [GeoPoint], bottomCovered: CGFloat) {
        // 상단 UI는 안전 영역 아래 8pt부터 시작한다(.padding(.top, 8)이 높이에 포함됨).
        let insets = MapInsets(top: screen.safeTop + topControlsHeight, bottom: bottomCovered)
        cameraAwayFromMe { mapState.fitCamera(to: points, insets: insets) }
    }

    /// 중간 높이로 멈춘 장소 결과 시트가 가리는 높이. BottomSheet의 medium과 같은 계산.
    private var mediumSheetHeight: CGFloat {
        (screen.height + screen.safeBottom) * BottomSheetDetent.mediumRatio
    }

    /// 내 위치가 아닌 곳(검색 결과, 경로)으로 카메라를 옮긴다. 따라가기를 먼저 꺼야
    /// 트래킹이 카메라를 내 위치로 되돌리지 않는다.
    private func cameraAwayFromMe(_ move: () -> Void) {
        viewModel.stopFollowing()
        move()
    }

    private func syncPlaceMarkers() {
        // 길찾기 중에는 검색 결과 마커를 숨기고 출발·도착 마커만 보인다.
        guard !route.isActive else {
            mapState.showPlaceMarkers([], selectedID: nil)
            return
        }
        let markers = search.places.enumerated().map { index, place in
            PlaceMarker(id: place.id, point: place.location, number: index + 1)
        }
        mapState.showPlaceMarkers(markers, selectedID: search.selectedPlace?.id)
    }

    // MARK: - 이펙트

    private func consumeMapEffects() async {
        for await effect in viewModel.effects {
            switch effect {
            case let .moveCamera(point, zoom):
                // 내 위치(첫 위치, 내 위치 버튼)는 애니메이션 없이 바로 놓는다.
                // 멀리서 날아오면 어색하고, 긴 이동 애니메이션은 도중에 끊겨 엉뚱한 곳에 멈출 수 있다.
                mapState.moveCamera(to: point, zoom: zoom, animated: false)
            case let .showError(error):
                toastMessage = error.userMessage
            case let .showMessage(message):
                toastMessage = message
            case .requestLocationPermission:
                await viewModel.requestLocationPermission()
            }
        }
    }

    private func consumeRouteEffects() async {
        for await effect in route.effects {
            switch effect {
            case let .fitCamera(points):
                // 아래 경로 카드는 이 effect와 같은 상태 변경으로 이제 막 바뀐다(목록이 닫히는 중일 수도 있다).
                // 다시 그려진 뒤의 실제 높이로 맞춘다.
                try? await Task.sleep(for: .milliseconds(150))
                fitCamera(to: points, bottomCovered: routeCardHeight + screen.safeBottom)
            case let .showError(error):
                mapState.showRoute(nil)
                toastMessage = error.userMessage
            case let .showMessage(message):
                toastMessage = message
            }
        }
    }

    private func consumeSearchEffects() async {
        for await effect in search.effects {
            switch effect {
            case let .fitCamera(points):
                fitCamera(to: points, bottomCovered: mediumSheetHeight)
            case let .focus(point):
                cameraAwayFromMe { mapState.moveCamera(to: point, zoom: 17) }
            case let .showError(error):
                toastMessage = error.userMessage
            }
        }
    }
}

/// 화면 높이와 안전 영역. 카메라 여백을 계산할 때 쓴다.
private struct ScreenMetrics: Equatable {
    var height: CGFloat = 0
    var safeTop: CGFloat = 0
    var safeBottom: CGFloat = 0
}

private func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}

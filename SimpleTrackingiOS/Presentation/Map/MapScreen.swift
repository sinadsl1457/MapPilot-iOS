import SwiftUI

struct MapScreen: View {
    let kakaoNativeAppKey: String
    let viewModel: MapViewModel
    let search: PlaceSearchViewModel
    let route: RouteViewModel

    @State private var mapState = KakaoMapState()
    @State private var toastMessage: String?
    @State private var sheetDetent: BottomSheetDetent = .medium
    @State private var sheetHeight: CGFloat = 0
    @State private var routeCardHeight: CGFloat = 0
    @State private var transitSheetDetent: BottomSheetDetent = .medium
    /// 상단 UI(검색창·칩 또는 길찾기 카드·탭)의 높이. 카메라를 맞출 때 위쪽 여백이 된다.
    @State private var topControlsHeight: CGFloat = 0
    /// 화면 높이와 위·아래 안전 영역. 카메라 여백 계산에 쓴다(지도는 안전 영역까지 덮는다).
    @State private var screen = ScreenMetrics()
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
        .onChange(of: route.isActive) { syncPlaceMarkers() }
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

    private var content: some View {
        GeometryReader { geometry in
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            // 시트가 있으면 시트 윗변 위에, 없으면 화면 아래에 붙인다.
            let floatingBottom = if route.isActive && route.selectedMode == .transit {
                sheetHeight + 12
            } else if route.isActive {
                routeCardHeight + bottomSafeArea + 12
            } else if isSheetVisible {
                sheetHeight + 12
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

                if let destination = route.destination {
                    VStack(spacing: 8) {
                        RouteHeader(destinationName: destination.name, onClose: closeRoute)
                        TravelModeTabs(selected: route.selectedMode, results: route.results) { mode in
                            withAnimation(.spring(duration: 0.3)) { route.selectMode(mode) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topControlsHeight = $0 }
                } else {
                    VStack(spacing: 8) {
                        MapSearchBar(
                            keyword: search.keyword,
                            showsClear: isSheetVisible,
                            onTap: search.openSearchPage,
                            onClear: search.clearResults
                        )
                        .padding(.horizontal, 16)

                        CategoryChips(selected: search.selectedCategory) { category in
                            Task { await search.toggleCategory(category, around: searchCenter) }
                        }
                    }
                    .padding(.top, 8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topControlsHeight = $0 }
                }

                if isSheetVisible {
                    BottomSheet(detent: $sheetDetent, visibleHeight: $sheetHeight) {
                        PlaceResultsHeader(viewModel: search)
                    } content: {
                        PlaceResultsContent(viewModel: search, myLocation: viewModel.myLocation?.point, onRoute: startRoute)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom))
                }

                if route.isActive && route.selectedMode == .transit {
                    BottomSheet(detent: $transitSheetDetent, visibleHeight: $sheetHeight, topReservedHeight: 160) {
                        TransitRouteListHeader(result: route.selectedResult)
                    } content: {
                        TransitRouteList(result: route.selectedResult, selectedIndex: route.selectedTransitIndex) { index in
                            route.selectTransitRoute(at: index)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom))
                } else if route.isActive {
                    RouteSummaryCard(mode: route.selectedMode, result: route.selectedResult)
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
            .animation(.spring(duration: 0.3), value: route.isActive)
            .animation(.spring(duration: 0.3), value: route.selectedMode)
            .overlay {
                if search.isSearchPagePresented {
                    SearchPage(viewModel: search, center: viewModel.myLocation?.point)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: search.isSearchPagePresented)
        }
    }

    private var missingKeyNotice: some View {
        ContentUnavailableView(
            "map.missingKey.title",
            systemImage: "key.slash",
            description: Text("map.missingKey.description")
        )
    }

    /// 카테고리 검색 기준: 지금 보고 있는 지도 중심 → 내 위치 → 기본 위치.
    private var searchCenter: GeoPoint {
        mapState.cameraCenter ?? viewModel.myLocation?.point ?? KakaoMapController.defaultCenter
    }

    private func startRoute(to place: Place) {
        // 권한이 없으면 길찾기 대신 권한부터 요청한다.
        guard viewModel.hasLocationPermission else {
            viewModel.onMyLocationButtonTapped()
            return
        }
        transitSheetDetent = .medium
        Task { await route.start(to: place, from: viewModel.myLocation?.point) }
    }

    private func closeRoute() {
        route.close()
        mapState.showRoute(nil)
        if let place = search.selectedPlace {
            cameraAwayFromMe { mapState.moveCamera(to: place.location, zoom: 17) }
        }
    }

    /// [points]가 위 UI와 아래 UI([bottomCovered]) 사이, 실제로 보이는 곳에 들어오게 맞춘다.
    /// 아래 시트는 펼쳐지는 중일 수 있어 지금 높이가 아니라 멈출 높이를 넘겨받는다.
    private func fitCamera(to points: [GeoPoint], bottomCovered: CGFloat) {
        // 상단 UI는 안전 영역 아래 8pt부터 시작한다(.padding(.top, 8)이 높이에 포함됨).
        let insets = MapInsets(top: screen.safeTop + topControlsHeight, bottom: bottomCovered)
        cameraAwayFromMe { mapState.fitCamera(to: points, insets: insets) }
    }

    /// 중간 높이로 멈춘 하단 시트(장소 결과·대중교통 목록)가 가리는 높이. BottomSheet의 medium과 같은 계산.
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
                if route.selectedMode == .transit {
                    fitCamera(to: points, bottomCovered: mediumSheetHeight)
                } else {
                    // 경로 카드는 이 effect와 같은 상태 변경으로 이제 막 바뀐다. 다시 그려진 뒤의 실제 높이로 맞춘다.
                    try? await Task.sleep(for: .milliseconds(50))
                    fitCamera(to: points, bottomCovered: routeCardHeight + screen.safeBottom)
                }
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

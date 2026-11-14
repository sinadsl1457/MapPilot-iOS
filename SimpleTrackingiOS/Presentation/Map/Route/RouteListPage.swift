import SwiftUI

/// 길찾기 경로 목록(전체 화면, 지도 없음). 네이버 지도의 대중교통 경로 목록처럼 경로를 골라야 지도에 그린다.
/// 경로를 누르거나 자동차·도보 탭을 고르면(경로가 하나라 고를 게 없다) `isShowingRoute`가 켜져 닫히고 지도에 그 경로가 보인다.
/// ✕는 길찾기 종료. 상태는 지도 화면과 같은 RouteViewModel(지도 화면이 아래에 살아 있어 유지된다).
/// 여는 곳: MapScreen(`route.isShowingList`일 때 fullScreenCover)
struct RouteListPage: View {
    let route: RouteViewModel
    /// 출발지·도착지를 바꿀 때 "내 위치"의 좌표, 선택 페이지의 거리 표시 기준.
    let myLocation: GeoPoint?
    let makeEndpointSearch: () -> EndpointSearchViewModel

    @State private var picking: EndpointRole?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    RouteHeader(
                        originName: route.origin?.title,
                        destinationName: route.destination?.title,
                        onTapOrigin: { picking = .origin },
                        onTapDestination: { picking = .destination },
                        onSwap: { Task { await route.swap(myLocation: myLocation) } },
                        onClose: route.close
                    )
                    TravelModeTabs(selected: route.selectedMode, results: route.results) { mode in
                        route.selectMode(mode)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                Divider()

                // 자동차·도보 탭이면 곧 닫히므로(지도로) 대중교통 목록만 그린다.
                if route.selectedMode == .transit {
                    TransitRouteListHeader(result: route.selectedResult)
                        .padding(.top, 12)
                    TransitRouteList(result: route.selectedResult, selectedIndex: nil) { index in
                        route.showRoute(at: index)
                    }
                }
                Spacer(minLength: 0)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $picking) { role in
                EndpointPickerPage(
                    viewModel: makeEndpointSearch(),
                    title: role.title,
                    myLocation: myLocation,
                    onPick: { endpoint in
                        picking = nil
                        Task {
                            switch role {
                            case .origin: await route.changeOrigin(endpoint, myLocation: myLocation)
                            case .destination: await route.changeDestination(endpoint, myLocation: myLocation)
                            }
                        }
                    },
                    onBack: { picking = nil }
                )
            }
        }
    }
}

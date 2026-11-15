import SwiftUI

/// 출발지·도착지 선택 페이지를 여는 대상.
enum EndpointRole: Hashable, Identifiable {
    case origin, destination

    var id: Self { self }

    var title: String {
        switch self {
        case .origin: String(localized: "route.picker.origin")
        case .destination: String(localized: "route.picker.destination")
        }
    }
}

/// 지도 첫 화면의 길찾기 버튼으로 여는 준비 화면.
/// 출발지(기본: 내 위치)·도착지·이동 수단을 정하고, 두 지점이 정해지면 `onComplete(plan)`으로 닫힌다.
struct RoutePlannerPage: View {
    @State private var viewModel: RoutePlannerViewModel
    let myLocation: GeoPoint?
    let makeEndpointSearch: () -> EndpointSearchViewModel
    let onComplete: (RoutePlan) -> Void
    let onClose: () -> Void

    @State private var picking: EndpointRole?

    init(
        viewModel: RoutePlannerViewModel,
        myLocation: GeoPoint?,
        makeEndpointSearch: @escaping () -> EndpointSearchViewModel,
        onComplete: @escaping (RoutePlan) -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.myLocation = myLocation
        self.makeEndpointSearch = makeEndpointSearch
        self.onComplete = onComplete
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RouteHeader(
                    originName: viewModel.origin?.title,
                    destinationName: viewModel.destination?.title,
                    onTapOrigin: { picking = .origin },
                    onTapDestination: { picking = .destination },
                    onSwap: viewModel.swap,
                    onClose: onClose
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ModeIconTabs(selected: viewModel.mode, onSelect: viewModel.selectMode)
                    .padding(.bottom, 8)
                Divider()
                recentPlaceList
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $picking) { role in
                EndpointPickerPage(
                    viewModel: makeEndpointSearch(),
                    title: role.title,
                    myLocation: myLocation,
                    onPick: { endpoint in
                        picking = nil
                        switch role {
                        case .origin: viewModel.setOrigin(endpoint)
                        case .destination: viewModel.setDestination(endpoint)
                        }
                    },
                    onBack: { picking = nil }
                )
            }
        }
        .task { await viewModel.onAppear() }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case let .completed(plan): onComplete(plan)
                }
            }
        }
    }

    @ViewBuilder
    private var recentPlaceList: some View {
        if viewModel.recentPlaces.isEmpty {
            Text("route.recentPlaces.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
            Spacer()
        } else {
            List(viewModel.recentPlaces, id: \.place.id) { recent in
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.chooseRecent(recent) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recent.place.name).lineLimit(1)
                                Text(recent.place.address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(recent.usedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await viewModel.removeRecent(recent) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("search.recent.remove \(recent.place.name)"))
                }
            }
            .listStyle(.plain)
        }
    }
}

/// 이동 수단 아이콘 탭. 아직 결과가 없어 시간 대신 아이콘만 보여준다.
private struct ModeIconTabs: View {
    let selected: TravelMode
    let onSelect: (TravelMode) -> Void

    var body: some View {
        HStack {
            ForEach(TravelMode.allCases, id: \.self) { mode in
                let isSelected = mode == selected
                Button {
                    onSelect(mode)
                } label: {
                    Image(systemName: mode.symbolName)
                        .frame(width: 64, height: 40)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .background(isSelected ? Color.accentColor : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
        }
    }
}

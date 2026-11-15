import SwiftUI

/// 길찾기 출발지·도착지를 고르는 페이지. 맨 위 "내 위치", 입력 중이면 실시간 검색 결과, 비어 있으면 최근 검색어.
/// 고른 지점을 `onPick`으로 돌려준다(닫는 건 여는 쪽이 한다).
/// 여는 곳: RoutePlannerPage, RouteListPage, MapScreen(자동차·도보 경로를 보는 중 카드 탭)
struct EndpointPickerPage: View {
    @State private var viewModel: EndpointSearchViewModel
    /// "출발지" 또는 "도착지"
    let title: String
    /// 거리 표시 기준. 없으면 거리를 보여주지 않는다.
    let myLocation: GeoPoint?
    let onPick: (RouteEndpoint) -> Void
    let onBack: () -> Void

    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    init(
        viewModel: EndpointSearchViewModel,
        title: String,
        myLocation: GeoPoint?,
        onPick: @escaping (RouteEndpoint) -> Void,
        onBack: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.myLocation = myLocation
        self.onPick = onPick
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            List {
                Button {
                    onPick(.myLocation)
                } label: {
                    Label {
                        Text("route.origin.myLocation")
                    } icon: {
                        Image(systemName: "location.fill").foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)

                switch viewModel.results {
                case nil:
                    recents
                case let places? where places.isEmpty:
                    emptyText("search.results.empty")
                case let places?:
                    ForEach(places, id: \.id) { place in
                        Button {
                            Task { await viewModel.remember(place) }
                            onPick(.place(place))
                        } label: {
                            PlaceRow(place: place, distance: DistanceText.string(from: myLocation, to: place.location))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .toast(message: $errorMessage, bottomInset: 24)
        .task { await viewModel.onAppear() }
        .task {
            for await error in viewModel.errors { errorMessage = error.userMessage }
        }
        .onAppear { isFieldFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.title3.weight(.medium))
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("common.back"))

            TextField(String(localized: "route.picker.placeholder \(title)"), text: $viewModel.query)
                .focused($isFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { Task { await viewModel.submit(center: myLocation) } }
                .onChange(of: viewModel.query) { _, text in
                    viewModel.onQueryChanged(text, center: myLocation)
                }

            if viewModel.isSubmitting {
                ProgressView().padding(.trailing, 8)
            } else if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("search.clearText"))
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var recents: some View {
        if viewModel.recentQueries.isEmpty {
            emptyText("search.recent.empty")
        } else {
            Section {
                ForEach(viewModel.recentQueries, id: \.self) { recent in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Button(recent) {
                            Task { await viewModel.searchRecent(recent, center: myLocation) }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .accessibilityLabel(Text("search.recent.remove \(recent)"))
                    }
                }
            } header: {
                Text("search.recent.title")
            }
        }
    }

    private func emptyText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .listRowSeparator(.hidden)
    }
}

/// 장소 한 줄: 이름 + 분류, 거리 · 주소.
private struct PlaceRow: View {
    let place: Place
    let distance: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.name).fontWeight(.semibold)
                    Text(place.category).font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Text([distance, place.address].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

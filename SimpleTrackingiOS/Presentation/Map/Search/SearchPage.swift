import SwiftUI

/// 검색창을 누르면 열리는 전체 화면 검색 페이지.
/// 입력 중이면 실시간 미리보기(입력이 0.3초 멈추면 검색), 비어 있으면 최근 검색어.
struct SearchPage: View {
    @Bindable var viewModel: PlaceSearchViewModel
    let center: GeoPoint?

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    viewModel.closeSearchPage()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.title3.weight(.medium))
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.back"))

                TextField("search.placeholder", text: $viewModel.query)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.submit(center: center) } }
                    .onChange(of: viewModel.query) { _, text in
                        viewModel.onQueryChanged(text, center: center)
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

            Divider()

            if !viewModel.suggestFor.isEmpty {
                suggestionList
            } else if viewModel.recentQueries.isEmpty {
                Text("search.recent.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                Spacer()
            } else {
                recentList
            }
        }
        .background(Color(.systemBackground))
        .onAppear { isFieldFocused = true }
    }

    /// 받는 중에는 이전 결과를 그대로 보여 주고(로딩 표시 없음), 지금 입력의 결과가 비었을 때만 안내 문구.
    @ViewBuilder
    private var suggestionList: some View {
        if viewModel.isSuggestionEmpty {
            Text("search.suggest.empty \(viewModel.suggestFor)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            Spacer()
        } else {
            List(viewModel.suggestions, id: \.id) { place in
                Button {
                    Task { await viewModel.pickSuggestion(place) }
                } label: {
                    SuggestionRow(place: place, distance: DistanceText.string(from: center, to: place.location))
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var recentList: some View {
        List {
            Section {
                ForEach(viewModel.recentQueries, id: \.self) { recent in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Button(recent) {
                            Task { await viewModel.searchRecent(recent, center: center) }
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
                HStack {
                    Text("search.recent.title")
                    Spacer()
                    Button("search.recent.clearAll") {
                        Task { await viewModel.clearRecents() }
                    }
                    .font(.footnote)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
    }
}

/// 미리보기 한 줄: 장소 이름, 거리 · 주소.
private struct SuggestionRow: View {
    let place: Place
    let distance: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .lineLimit(1)
                Text([distance, place.address].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

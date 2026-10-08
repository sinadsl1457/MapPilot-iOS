import SwiftUI

/// 검색창을 누르면 열리는 전체 화면 검색 페이지. 최근 검색어를 보여준다.
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

            if viewModel.recentQueries.isEmpty {
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

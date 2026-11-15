import SwiftUI

/// 하단 시트의 머리글: 결과 제목과 개수, 닫기 버튼.
struct PlaceResultsHeader: View {
    let viewModel: PlaceSearchViewModel

    var body: some View {
        if viewModel.selectedPlace == nil {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if case let .loaded(places) = viewModel.phase, !places.isEmpty {
                    Text("search.results.count \(places.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var title: String {
        switch viewModel.source {
        case let .keyword(keyword): keyword
        case let .category(category): category.title
        case nil: ""
        }
    }
}

/// 하단 시트 본문: 검색 결과 목록 또는 선택한 장소 상세.
struct PlaceResultsContent: View {
    let viewModel: PlaceSearchViewModel
    let myLocation: GeoPoint?
    let onRoute: (Place) -> Void

    var body: some View {
        if let place = viewModel.selectedPlace {
            PlaceDetailView(
                place: place,
                distance: DistanceText.string(from: myLocation, to: place.location),
                onBack: viewModel.deselectPlace,
                onRoute: { onRoute(place) }
            )
        } else {
            switch viewModel.phase {
            case .loading, nil:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            case let .loaded(places) where places.isEmpty:
                Text("search.results.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            case let .loaded(places):
                // 스크롤은 시트(BottomSheet)가 맡는다. List를 쓰면 목록이 따로 스크롤돼 시트가 끝까지 올라가지 않는다.
                VStack(spacing: 0) {
                    ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                        Button {
                            viewModel.select(place)
                        } label: {
                            PlaceRow(number: index + 1, place: place, distance: DistanceText.string(from: myLocation, to: place.location))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 54)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

private struct PlaceRow: View {
    let number: Int
    let place: Place
    let distance: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(place.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(place.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    if let distance {
                        Text(distance).foregroundStyle(.primary)
                        Text(verbatim: "·").foregroundStyle(.tertiary)
                    }
                    Text(place.address).foregroundStyle(.secondary).lineLimit(1)
                }
                .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct PlaceDetailView: View {
    let place: Place
    let distance: String?
    let onBack: () -> Void
    let onRoute: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                Spacer()
                Button("search.backToList", action: onBack)
                    .font(.subheadline)
            }

            HStack(spacing: 4) {
                Text(place.category)
                if let distance {
                    Text(verbatim: "·").foregroundStyle(.tertiary)
                    Text(distance)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Label(place.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline)

            if !place.phone.isEmpty {
                Button {
                    let digits = place.phone.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel://\(digits)") { openURL(url) }
                } label: {
                    Label(place.phone, systemImage: "phone")
                        .font(.subheadline)
                }
            }

            Button(action: onRoute) {
                Label("route.start", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

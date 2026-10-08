import SwiftUI

/// 대중교통 하단 시트 머리글.
struct TransitRouteListHeader: View {
    let result: RouteViewModel.ModeResult?

    var body: some View {
        HStack {
            Label("travelMode.transit", systemImage: TravelMode.transit.symbolName)
                .font(.headline)
            if case let .transit(routes) = result {
                Text("route.transit.count \(routes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

/// 대중교통 경로 후보 목록. 하나를 고르면 지도에 그 경로를 그린다.
struct TransitRouteList: View {
    let result: RouteViewModel.ModeResult?
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        switch result {
        case let .transit(routes):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                        Button {
                            onSelect(index)
                        } label: {
                            TransitRouteRow(route: route, isSelected: index == selectedIndex)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 20)
                    }
                }
            }
        case let .failed(error):
            RouteFailureText(error: error)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        case .loading, .route, nil:
            HStack(spacing: 10) {
                ProgressView()
                Text("route.loading").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
    }
}

private struct TransitRouteRow: View {
    let route: TransitRoute
    let isSelected: Bool

    private var rideLegs: [TransitLeg] { route.legs.filter { $0.kind != .walk } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DurationText.string(seconds: route.durationSeconds))
                    .font(.title3.weight(.bold))
                Text("route.arrival \(ArrivalTime.string(after: route.durationSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            TransitSegmentBar(legs: route.legs)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rideLegs.enumerated()), id: \.offset) { _, leg in
                    TransitLegLine(leg: leg)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Color.accentColor).frame(width: 3)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var detailLine: String {
        var parts: [String] = []
        parts.append(route.transfers == 0
            ? String(localized: "route.transfers.none")
            : String(localized: "route.transfers \(route.transfers)"))
        if let fare = route.fare {
            parts.append(String(localized: "route.fare \(fare.formatted())"))
        }
        parts.append(DistanceText.string(meters: Double(route.distanceMeters)))
        return parts.joined(separator: " · ")
    }
}

/// 구간별 소요 시간 비율 막대. 색은 지도 경로 선과 같다.
private struct TransitSegmentBar: View {
    let legs: [TransitLeg]

    var body: some View {
        GeometryReader { geometry in
            let total = max(1, legs.reduce(0) { $0 + $1.durationSeconds })
            let spacing: CGFloat = 2
            let available = geometry.size.width - spacing * CGFloat(max(0, legs.count - 1))
            HStack(spacing: spacing) {
                ForEach(Array(legs.enumerated()), id: \.offset) { _, leg in
                    let width = max(14, available * CGFloat(leg.durationSeconds) / CGFloat(total))
                    Capsule()
                        .fill(RouteColors.leg(leg.kind).opacity(leg.kind == .walk ? 0.45 : 1))
                        .frame(width: width)
                        .overlay {
                            if width > 36 {
                                Text(verbatim: "\(max(1, leg.durationSeconds / 60))")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

/// "🚇 수인분당선  태평 → 왕십리 · 14개 정류장"
private struct TransitLegLine: View {
    let leg: TransitLeg

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leg.kind.symbolName)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RouteColors.leg(leg.kind), in: Circle())

            Text(leg.lineNames.isEmpty ? leg.guidance : leg.lineNames.joined(separator: ", "))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if let from = leg.stops.first, let to = leg.stops.last {
                Text(verbatim: "\(from) → \(to)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if leg.stops.count > 1 {
                Text("route.stops \(leg.stops.count - 1)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
    }
}

import SwiftUI

/// 자동차·도보 길찾기 하단 카드: 예상 시간, 거리, 도착 예정 시각.
struct RouteSummaryCard: View {
    let mode: TravelMode
    let result: RouteViewModel.ModeResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(mode.title, systemImage: mode.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: Capsule())

            switch result {
            case let .route(route):
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(DurationText.string(seconds: route.durationSeconds))
                        .font(.title.weight(.bold))
                    Text(DistanceText.string(meters: Double(route.distanceMeters)))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("route.arrival \(ArrivalTime.string(after: route.durationSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let fares = fareLine(route) {
                    Text(fares)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case let .failed(error):
                RouteFailureText(error: error)
                    .frame(height: 60, alignment: .leading)
            case .loading, .transit, nil:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("route.loading").foregroundStyle(.secondary)
                }
                .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private extension RouteSummaryCard {
    /// "택시 약 26,800원 · 통행료 1,200원". 통행료가 없으면 생략한다.
    func fareLine(_ route: Route) -> String? {
        var parts: [String] = []
        if let taxi = route.taxiFare, taxi > 0 {
            parts.append(String(localized: "route.fare.taxi \(taxi.formatted())"))
        }
        if let toll = route.tollFare, toll > 0 {
            parts.append(String(localized: "route.fare.toll \(toll.formatted())"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct RouteFailureText: View {
    let error: DomainError

    var body: some View {
        Label(error.userMessage, systemImage: "exclamationmark.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

enum ArrivalTime {
    static func string(after seconds: Int, from now: Date = .now) -> String {
        now.addingTimeInterval(TimeInterval(seconds)).formatted(date: .omitted, time: .shortened)
    }
}

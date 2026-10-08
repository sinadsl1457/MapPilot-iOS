import SwiftUI

/// 길찾기 중 하단에 뜨는 요약 카드: 예상 시간, 거리, 도착 예정 시각.
struct RouteSummaryCard: View {
    let phase: RouteViewModel.Phase?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("route.mode.car", systemImage: "car.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: Capsule())

            switch phase {
            case let .loaded(route):
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(DurationText.string(seconds: route.durationSeconds))
                        .font(.title.weight(.bold))
                    Text(DistanceText.string(meters: Double(route.distanceMeters)))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("route.arrival \(arrivalTime(after: route.durationSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .loading, nil:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("route.loading")
                        .foregroundStyle(.secondary)
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

    private func arrivalTime(after seconds: Int) -> String {
        Date.now.addingTimeInterval(TimeInterval(seconds)).formatted(date: .omitted, time: .shortened)
    }
}

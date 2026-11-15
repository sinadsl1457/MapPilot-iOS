import SwiftUI

/// 길찾기 상단의 이동 수단 탭. 탭마다 소요 시간을 미리 보여준다.
struct TravelModeTabs: View {
    let selected: TravelMode
    let results: [TravelMode: RouteViewModel.ModeResult]
    let onSelect: (TravelMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TravelMode.allCases, id: \.self) { mode in
                let isSelected = mode == selected
                Button {
                    onSelect(mode)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.symbolName)
                        summary(for: mode)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background(isSelected ? Color.accentColor : Color(.systemBackground), in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "\(mode.title) \(accessibilitySummary(for: mode))"))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func summary(for mode: TravelMode) -> some View {
        switch results[mode] {
        case .loading, nil:
            ProgressView().controlSize(.mini)
        case let .route(route):
            Text(DurationText.string(seconds: route.durationSeconds))
        case let .transit(routes):
            Text(DurationText.string(seconds: routes.first?.durationSeconds ?? 0))
        case .failed:
            Text(verbatim: "–")
        }
    }

    private func accessibilitySummary(for mode: TravelMode) -> String {
        switch results[mode] {
        case let .route(route): DurationText.string(seconds: route.durationSeconds)
        case let .transit(routes): DurationText.string(seconds: routes.first?.durationSeconds ?? 0)
        case .failed: String(localized: "route.unavailable")
        case .loading, nil: String(localized: "route.loading")
        }
    }
}

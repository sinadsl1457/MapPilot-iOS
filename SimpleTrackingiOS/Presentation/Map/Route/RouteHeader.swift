import SwiftUI

/// 출발지·도착지 카드. 길찾기 준비 화면, 경로 목록, 지도 위(자동차·도보)가 같이 쓴다.
/// 줄을 누르면 그 지점을 바꾸고, ⇅로 두 지점을 맞바꾼다. 이름이 nil이면 "출발지 입력"·"도착지 입력"을 흐리게 보여준다.
struct RouteHeader: View {
    let originName: String?
    let destinationName: String?
    let onTapOrigin: () -> Void
    let onTapDestination: () -> Void
    let onSwap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 두 줄 사이 높이에 오도록 가운데에 둔다.
            iconButton("arrow.up.arrow.down", label: "route.swap", action: onSwap)
            VStack(alignment: .leading, spacing: 0) {
                row(color: RouteColors.start, name: originName, placeholder: "route.origin.placeholder",
                    label: "route.origin.change", action: onTapOrigin)
                Divider().padding(.leading, 24)
                row(color: RouteColors.end, name: destinationName, placeholder: "route.destination.placeholder",
                    label: "route.destination.change", action: onTapDestination)
            }
            iconButton("xmark", label: "route.close", action: onClose)
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private func iconButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private func row(
        color: Color, name: String?, placeholder: LocalizedStringKey, label: LocalizedStringKey, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Group {
                    if let name {
                        Text(verbatim: name)
                    } else {
                        Text(placeholder).foregroundStyle(.secondary)
                    }
                }
                .font(.body)
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(label))
    }
}

extension RouteEndpoint {
    /// 표시 이름: "내 위치" 또는 장소 이름.
    var title: String {
        switch self {
        case .myLocation: String(localized: "route.origin.myLocation")
        case let .place(place): place.name
        }
    }
}

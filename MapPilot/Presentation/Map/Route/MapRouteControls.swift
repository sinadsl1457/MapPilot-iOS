import SwiftUI

/// 검색창 오른쪽의 파란 길찾기 버튼. 누르면 길찾기 준비 화면(RoutePlannerPage)이 열린다.
struct DirectionsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("route.start"))
    }
}

/// 대중교통 경로를 지도에서 보는 중 상단: ‹(목록으로) + "출발 → 도착". 줄 어디를 눌러도 목록으로 간다.
struct RouteShownBar: View {
    let originName: String
    let destinationName: String
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.backward")
                    .font(.title3.weight(.medium))
                    .frame(width: 44, height: 44)
                Text(verbatim: "\(originName) → \(destinationName)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 20)
            }
            .padding(.leading, 6)
            .frame(height: 56)
            .background(Color(.systemBackground), in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("route.backToList"))
    }
}

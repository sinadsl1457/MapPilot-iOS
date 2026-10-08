import SwiftUI

/// 길찾기 중 상단에 뜨는 출발지·도착지 카드.
struct RouteHeader: View {
    let destinationName: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                row(color: RouteColors.start, title: Text("route.origin.myLocation"))
                Divider().padding(.leading, 26)
                row(color: RouteColors.end, title: Text(destinationName))
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("route.close"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private func row(color: Color, title: Text) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            title
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }
}

enum RouteColors {
    static let start = Color(red: 0x35 / 255, green: 0x6D / 255, blue: 0xF3 / 255)
    static let end = Color(red: 0xF2 / 255, green: 0x46 / 255, blue: 0x4B / 255)
}

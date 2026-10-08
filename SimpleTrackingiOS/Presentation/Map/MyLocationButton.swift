import SwiftUI

/// Apple 지도처럼 우하단에 떠 있는 원형 내 위치 버튼.
struct MyLocationButton: View {
    let hasPermission: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: hasPermission ? "location" : "location.slash")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(hasPermission ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("map.myLocation.label"))
        .accessibilityHint(Text(hasPermission ? "map.myLocation.hint.authorized" : "map.myLocation.hint.unauthorized"))
    }
}

#Preview {
    HStack(spacing: 24) {
        MyLocationButton(hasPermission: true) {}
        MyLocationButton(hasPermission: false) {}
    }
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

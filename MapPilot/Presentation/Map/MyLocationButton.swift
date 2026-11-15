import SwiftUI

/// Apple 지도처럼 우하단에 떠 있는 원형 내 위치 버튼. 아이콘으로 따라가기 모드를 보여 준다.
///
/// | 상태 | 아이콘 | 누르면 |
/// |---|---|---|
/// | 권한 없음 | location.slash(회색) | 권한 요청 |
/// | none (지도를 옮겨 둠) | location(검정) | 내 위치로 카메라만 이동 |
/// | none (카메라가 내 위치) | location(검정) | 따라가기 |
/// | follow | location.fill(파랑) | 지도 회전까지 |
/// | followWithHeading | location.north.line.fill(파랑) | 따라가기 해제 |
struct MyLocationButton: View {
    let hasPermission: Bool
    var followMode: FollowMode = .none
    var isCameraOnMyLocation = false
    let action: () -> Void

    private var symbol: String {
        guard hasPermission else { return "location.slash" }
        return switch followMode {
        case .none: "location"
        case .follow: "location.fill"
        case .followWithHeading: "location.north.line.fill"
        }
    }

    private var tint: Color {
        guard hasPermission else { return .secondary }
        return followMode == .none ? .primary : .accentColor
    }

    private var hint: Text {
        guard hasPermission else { return Text("map.myLocation.hint.unauthorized") }
        return switch followMode {
        case .none: Text(isCameraOnMyLocation ? "map.myLocation.hint.follow" : "map.myLocation.hint.move")
        case .follow: Text("map.myLocation.hint.rotate")
        case .followWithHeading: Text("map.myLocation.hint.stop")
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("map.myLocation.label"))
        .accessibilityHint(hint)
    }
}

#Preview {
    HStack(spacing: 24) {
        MyLocationButton(hasPermission: true) {}
        MyLocationButton(hasPermission: true, followMode: .follow) {}
        MyLocationButton(hasPermission: true, followMode: .followWithHeading) {}
        MyLocationButton(hasPermission: false) {}
    }
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

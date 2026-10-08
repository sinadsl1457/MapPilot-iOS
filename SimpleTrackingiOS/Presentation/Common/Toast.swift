import SwiftUI

/// 화면 아래에 잠깐 떴다 사라지는 안내 문구.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    /// 화면 아래에서 띄울 거리. 시트·버튼 위에 뜨도록 화면이 정한다.
    var bottomInset: CGFloat
    var duration: Duration = .seconds(2)

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    .padding(.horizontal, 24)
                    .padding(.bottom, bottomInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        AccessibilityNotification.Announcement(message).post()
                        try? await Task.sleep(for: duration)
                        self.message = nil
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, bottomInset: CGFloat) -> some View {
        modifier(ToastModifier(message: message, bottomInset: bottomInset))
    }
}

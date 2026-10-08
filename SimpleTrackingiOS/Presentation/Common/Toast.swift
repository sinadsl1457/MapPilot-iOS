import SwiftUI

/// 화면 아래에 잠깐 떴다 사라지는 안내 문구.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
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
                    .padding(.bottom, 96) // 내 위치 버튼과 겹치지 않게
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
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

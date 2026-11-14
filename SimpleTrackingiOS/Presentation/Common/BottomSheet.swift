import SwiftUI

/// 끌어서 높이를 바꾸는 하단 시트. 시스템 `.sheet`와 달리 지도 위에 직접 얹혀서,
/// 현재 높이(`visibleHeight`)를 알려 다른 버튼을 시트 위에 붙일 수 있다.
enum BottomSheetDetent: CaseIterable {
    case collapsed, medium, large

    /// 중간 높이 = 시트가 놓인 영역 높이의 이 비율. 카메라 여백 계산(MapScreen)도 같은 값을 쓴다.
    static let mediumRatio: CGFloat = 0.45
}

struct BottomSheet<Header: View, Content: View>: View {
    typealias Detent = BottomSheetDetent

    @Binding var detent: Detent
    /// 화면 아래 끝부터 시트 윗변까지의 높이.
    @Binding var visibleHeight: CGFloat
    /// 펼쳤을 때 위에 남겨 둘 공간(검색창 자리).
    var topReservedHeight: CGFloat = 72
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    @State private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let heights = detentHeights(containerHeight: geometry.size.height)
            let target = heights[detent] ?? 0
            let height = min(max(target - dragTranslation, heights[.collapsed, default: 0] * 0.7), heights[.large, default: 0])

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    header
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(dragGesture(heights: heights))

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geometry.size.width, height: height, alignment: .top)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .onChange(of: height, initial: true) { _, newHeight in
                visibleHeight = newHeight
            }
        }
    }

    private func detentHeights(containerHeight: CGFloat) -> [Detent: CGFloat] {
        [
            .collapsed: 230,
            .medium: containerHeight * BottomSheetDetent.mediumRatio,
            .large: containerHeight - topReservedHeight,
        ]
    }

    private func dragGesture(heights: [Detent: CGFloat]) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                // 손을 뗀 속도까지 고려해 가장 가까운 높이로 붙인다.
                let projected = (heights[detent] ?? 0) - value.predictedEndTranslation.height
                let nearest = Detent.allCases.min {
                    abs((heights[$0] ?? 0) - projected) < abs((heights[$1] ?? 0) - projected)
                } ?? detent
                withAnimation(.spring(duration: 0.3)) {
                    detent = nearest
                    dragTranslation = 0
                }
            }
    }
}

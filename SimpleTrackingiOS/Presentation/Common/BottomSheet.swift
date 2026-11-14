import SwiftUI
import UIKit

/// 하단 시트가 멈추는 높이.
enum BottomSheetDetent: CaseIterable {
    /// 장소 상세처럼 지도를 보며 짧은 내용만 보일 때
    case collapsed
    case medium
    /// 화면 맨 위(상태 표시줄 바로 아래)까지
    case large

    /// 중간 높이 = 상태 표시줄 아래 화면 높이의 이 비율. 카메라 여백 계산(MapScreen)도 같은 값을 쓴다.
    static let mediumRatio: CGFloat = 0.45
    static let collapsedHeight: CGFloat = 230
}

/// 지도 위에 직접 얹히는 하단 시트. 현재 높이(`visibleHeight`)를 알려 다른 버튼을 시트 위에 붙일 수 있다.
///
/// 시트 전체가 스크롤 뷰 하나다(위쪽은 비어 있고 그 아래에 카드가 있다). 그래서 목록을 위로 끌면 카드가 먼저
/// 화면 맨 위까지 올라가고, 다 올라가면 같은 손동작이 그대로 목록 스크롤로 이어진다(네이버·애플 지도 방식).
/// 맨 위에서 아래로 끌면 반대로 카드가 내려온다. 카드 위쪽 빈 곳의 터치는 아래 지도로 통과한다.
/// SwiftUI ScrollView는 빈 곳의 터치를 지도로 넘기지 못해 UIScrollView로 만든다.
struct BottomSheet<Header: View, Content: View>: UIViewControllerRepresentable {
    @Binding var detent: BottomSheetDetent
    /// 화면 아래 끝부터 카드 윗변까지의 높이.
    @Binding var visibleHeight: CGFloat
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    func makeUIViewController(context: Context) -> BottomSheetController {
        BottomSheetController(rootView: card, detent: detent)
    }

    func updateUIViewController(_ controller: BottomSheetController, context: Context) {
        controller.onDetentChange = { detent = $0 }
        controller.onHeightChange = { visibleHeight = $0 }
        controller.update(rootView: card, detent: detent)
    }

    private var card: AnyView {
        AnyView(SheetCard(header: header, content: content))
    }
}

/// 카드 모양: 손잡이 + 머리글 + 본문. 배경은 카드가 화면을 다 채울 만큼 아래로 늘어난다.
private struct SheetCard<Header: View, Content: View>: View {
    let header: Header
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.quaternary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
        )
    }
}

/// 시트의 UIKit 부분. 스크롤 위치(contentOffset)가 곧 시트 높이다.
/// offset 0 = 접힘(collapsed), 카드가 화면 맨 위에 닿는 offset = large, 그보다 더 가면 목록 스크롤.
final class BottomSheetController: UIViewController, UIScrollViewDelegate {
    var onDetentChange: ((BottomSheetDetent) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    private let scrollView = PassThroughScrollView()
    private let host: UIHostingController<AnyView>
    private var detent: BottomSheetDetent
    /// 카드 위 빈 공간 높이(= 화면 높이 - 접힌 높이).
    private var spacerConstraint: NSLayoutConstraint?
    /// 내용이 짧아도 카드가 화면 맨 위까지 올라갈 수 있게 하는 최소 높이.
    private var minHeightConstraint: NSLayoutConstraint?
    private var laidOutSize: CGSize = .zero
    private var lastReportedHeight: CGFloat = -1

    init(rootView: AnyView, detent: BottomSheetDetent) {
        host = UIHostingController(rootView: rootView)
        self.detent = detent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = PassThroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        addChild(host)
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        // 카드 안에서 안전 영역 여백을 또 넣지 않는다(위치는 이 컨트롤러가 정한다).
        host.safeAreaRegions = []
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        host.didMove(toParent: self)
        scrollView.cardView = host.view

        let content = scrollView.contentLayoutGuide
        let spacer = host.view.topAnchor.constraint(equalTo: content.topAnchor)
        let minHeight = host.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spacer,
            host.view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minHeight,
        ])
        spacerConstraint = spacer
        minHeightConstraint = minHeight
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        guard size.height > 0, size != laidOutSize else { return }
        laidOutSize = size
        spacerConstraint?.constant = size.height - BottomSheetDetent.collapsedHeight
        minHeightConstraint?.constant = size.height - view.safeAreaInsets.top
        scrollView.layoutIfNeeded()
        scrollView.contentOffset.y = offset(for: detent)
        reportHeight()
    }

    /// SwiftUI가 다시 그릴 때. 바깥에서 높이를 바꿨으면(장소 선택 → 접기 등) 그 높이로 움직인다.
    func update(rootView: AnyView, detent newDetent: BottomSheetDetent) {
        host.rootView = rootView
        guard newDetent != detent else { return }
        detent = newDetent
        guard laidOutSize != .zero else { return }
        scrollView.setContentOffset(CGPoint(x: 0, y: offset(for: newDetent)), animated: true)
    }

    // MARK: - 높이 계산

    private var screenHeight: CGFloat { laidOutSize.height }
    private var safeTop: CGFloat { view.safeAreaInsets.top }

    private func offset(for detent: BottomSheetDetent) -> CGFloat {
        let collapsed = BottomSheetDetent.collapsedHeight
        switch detent {
        case .collapsed: return 0
        case .medium: return (screenHeight - safeTop) * BottomSheetDetent.mediumRatio - collapsed
        case .large: return screenHeight - safeTop - collapsed
        }
    }

    /// 카드가 화면 맨 위에 닿은 뒤에는(목록 스크롤 중) 높이를 더 늘리지 않는다.
    private func reportHeight() {
        let height = min(BottomSheetDetent.collapsedHeight + scrollView.contentOffset.y, screenHeight - safeTop)
        let rounded = max(0, height.rounded())
        guard rounded != lastReportedHeight else { return }
        lastReportedHeight = rounded
        // SwiftUI가 화면을 그리는 중에 상태를 바꾸지 않도록 다음 차례에 알린다.
        DispatchQueue.main.async { [weak self] in self?.onHeightChange?(rounded) }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reportHeight()
    }

    /// 손을 뗄 때: 카드가 움직이는 구간(맨 위 아래)에서 멈출 거면 가장 가까운 높이로 붙인다.
    /// 이미 맨 위에서 목록을 스크롤하던 중이면 그대로 둔다.
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let full = offset(for: .large)
        let target = targetContentOffset.pointee.y
        let next: BottomSheetDetent
        if target >= full {
            next = .large
            // 맨 위 아래에서 위로 튕겨 올렸으면 맨 위에 멈춘다(목록은 다음 손동작부터 스크롤).
            if scrollView.contentOffset.y < full { targetContentOffset.pointee.y = full }
        } else {
            next = BottomSheetDetent.allCases.min { abs(offset(for: $0) - target) < abs(offset(for: $1) - target) } ?? detent
            targetContentOffset.pointee.y = offset(for: next)
        }
        if next != detent {
            detent = next
            DispatchQueue.main.async { [weak self] in self?.onDetentChange?(next) }
        }
    }
}

/// 카드 위쪽 빈 곳의 터치는 받지 않는다 → 아래 지도로 간다.
final class PassThroughScrollView: UIScrollView {
    weak var cardView: UIView?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // point는 스크롤된 내용 좌표라서 카드 frame과 바로 비교할 수 있다.
        guard let cardView else { return false }
        return point.y >= cardView.frame.minY && super.point(inside: point, with: event)
    }
}

/// 자기 자신은 터치를 받지 않고, 위에 올라온 하위 뷰(카드)만 받는다.
private final class PassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

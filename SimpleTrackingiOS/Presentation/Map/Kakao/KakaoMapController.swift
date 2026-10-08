@preconcurrency import KakaoMapsSDK
import UIKit

/// Kakao Maps SDK의 명령형 API를 모으는 곳. 엔진 수명주기, 카메라, 내 위치 마커를 맡는다.
/// SDK 타입은 이 폴더 밖으로 나가지 않는다.
@MainActor
final class KakaoMapController: NSObject {
    static let defaultCenter = GeoPoint(latitude: 37.5666, longitude: 126.9784) // 서울시청
    static let defaultZoom = 15

    private enum ID {
        static let mapView = "mapview"
        static let myLocationLayer = "myLocation"
        static let myLocationPoi = "myLocation.poi"
        static let dotStyle = "myLocation.dot"
        static let arrowStyle = "myLocation.arrow"
    }

    private static let markerAnimationMillis: UInt = 800
    private static let cameraAnimationMillis: UInt = 300
    private static var isSDKInitialized = false

    private let state: KakaoMapState
    private var controller: KMController?
    private weak var container: KMViewContainer?
    private var shouldBeActive = false

    private var map: KakaoMap? { controller?.getView(ID.mapView) as? KakaoMap }
    private var myLocationPoi: Poi?
    private var myLocationStyle: String?
    /// 마지막으로 적용한 회전값. 359° → 1°처럼 경계를 넘을 때 반대로 한 바퀴 돌지 않게 이어 붙인다.
    private var lastRoll: Double?

    init(appKey: String, state: KakaoMapState) {
        self.state = state
        super.init()
        if !Self.isSDKInitialized {
            SDKInitializer.InitSDK(appKey: appKey)
            Self.isSDKInitialized = true
        }
    }

    // MARK: - 엔진 수명주기 (KakaoMapView가 호출)

    func makeContainer() -> KMViewContainer {
        // SDK는 크기가 0인 컨테이너에서 뷰를 만들지 못하므로 임시 크기를 준다. 실제 크기는 레이아웃 후 containerDidResized로 들어온다.
        let container = KMViewContainer(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        // SDK는 제스처 인식기 대신 터치를 직접 받는다. UIView 기본값(false)이면 두 번째 손가락이 전달되지 않아 핀치 줌·회전이 안 된다.
        container.isMultipleTouchEnabled = true
        let controller = KMController(viewContainer: container)
        controller.delegate = self
        self.container = container
        self.controller = controller
        _ = controller.prepareEngine()
        return container
    }

    /// 엔진은 앱이 active일 때만 활성 상태여야 한다.
    func setActive(_ active: Bool) {
        shouldBeActive = active
        guard let controller else { return }
        if active {
            if !controller.isEnginePrepared { _ = controller.prepareEngine() }
            if !controller.isEngineActive { controller.activateEngine() }
        } else if controller.isEngineActive {
            controller.pauseEngine()
        }
    }

    func tearDown() {
        state.detach()
        myLocationPoi = nil
        controller?.pauseEngine()
        controller?.resetEngine()
        controller = nil
    }

    // MARK: - 지도 준비

    private func configureMyLocationLayer(on map: KakaoMap) {
        let labelManager = map.getLabelManager()
        let layerOptions = LabelLayerOptions(
            layerID: ID.myLocationLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10_000
        )
        _ = labelManager.addLabelLayer(option: layerOptions)
        labelManager.addPoiStyle(PoiStyle(styleID: ID.dotStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.dot()), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.arrowStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.arrow()), level: 0),
        ]))
    }

    private static func mapPoint(_ point: GeoPoint) -> MapPoint {
        MapPoint(longitude: point.longitude, latitude: point.latitude)
    }

    /// bearing(도, 북쪽 기준 시계방향) → POI roll(라디안).
    /// SDK 문서에 단위·방향이 적혀 있지 않아 실제 화면에서 확인해야 한다.
    private static func roll(fromBearing bearing: Double) -> Double {
        bearing * .pi / 180
    }

    private func continuousRoll(toward target: Double) -> Double {
        guard let lastRoll else { return target }
        var delta = (target - lastRoll).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return lastRoll + delta
    }
}

// MARK: - KakaoMapCommands

extension KakaoMapController: KakaoMapCommands {
    func moveCamera(to point: GeoPoint, zoom: Int) {
        guard let map else { return }
        map.animateCamera(
            cameraUpdate: CameraUpdate.make(target: Self.mapPoint(point), zoomLevel: zoom, mapView: map),
            options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
        )
    }

    func updateMyLocation(_ location: UserLocation?) {
        guard let layer = map?.getLabelManager().getLabelLayer(layerID: ID.myLocationLayer) else { return }

        guard let location else {
            layer.removePoi(poiID: ID.myLocationPoi)
            myLocationPoi = nil
            myLocationStyle = nil
            lastRoll = nil
            return
        }

        let point = Self.mapPoint(location.point)
        let style = location.bearing == nil ? ID.dotStyle : ID.arrowStyle

        if let poi = myLocationPoi {
            if style != myLocationStyle {
                poi.changeStyle(styleID: style)
                myLocationStyle = style
            }
            poi.moveAt(point, duration: Self.markerAnimationMillis)
            if let bearing = location.bearing {
                let roll = continuousRoll(toward: Self.roll(fromBearing: bearing))
                poi.rotateAt(roll, duration: Self.markerAnimationMillis)
                lastRoll = roll
            }
        } else {
            let options = PoiOptions(styleID: style, poiID: ID.myLocationPoi)
            options.rank = Int(Int32.max)
            options.clickable = false
            // 지도를 돌려도 실제 방위를 가리키도록 절대 회전을 쓴다.
            options.transformType = .absoluteRotation
            guard let poi = layer.addPoi(option: options, at: point) else { return }
            if let bearing = location.bearing {
                let roll = Self.roll(fromBearing: bearing)
                poi.rotateAt(roll, duration: 0)
                lastRoll = roll
            }
            poi.show()
            myLocationPoi = poi
            myLocationStyle = style
        }
    }
}

// MARK: - MapControllerDelegate

extension KakaoMapController: @preconcurrency MapControllerDelegate {
    func addViews() {
        let info = MapviewInfo(
            viewName: ID.mapView,
            viewInfoName: "map",
            defaultPosition: Self.mapPoint(Self.defaultCenter),
            defaultLevel: Self.defaultZoom
        )
        controller?.addView(info)
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        guard let map else { return }
        if let container {
            map.viewRect = container.bounds
        }
        configureMyLocationLayer(on: map)
        state.attach(self)
    }

    func addViewFailed(_ viewName: String, viewInfoName: String) {
        state.fail("addView(\(viewName)) failed")
    }

    func containerDidResized(_ size: CGSize) {
        map?.viewRect = CGRect(origin: .zero, size: size)
    }

    func authenticationFailed(_ errorCode: Int, desc: String) {
        state.fail("\(desc) (\(errorCode))")
    }
}

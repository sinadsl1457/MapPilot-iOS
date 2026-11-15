@preconcurrency import KakaoMapsSDK
import UIKit

import CoreLocation

/// Kakao Maps SDK의 명령형 API를 모으는 곳. 엔진 수명주기, 카메라, 내 위치 마커를 맡는다.
/// SDK 타입은 이 폴더 밖으로 나가지 않는다.
///
/// - 나침반(정지 중 폰이 향한 방향): CompassHeading 값으로 따라가기 꺼짐이면 점의 화살촉을, 따라가기 중이면 점 아래 콘을 돌린다.
/// - 따라가기: SDK TrackingManager가 내 위치 POI를 카메라로 따라간다. 사용자가 드래그하면 state에 알려 해제하게 한다.
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
        static let headingDotStyle = "myLocation.headingDot"
        static let conePoi = "myLocation.cone"
        static let coneStyle = "myLocation.cone.style"
        static let placeLayer = "places"
        static let routeLayer = "route"
        static func routeStyle(_ kind: RouteLine.Kind) -> String { "route.style.\(kind)" }
        static func routeStyle(rgb: UInt32) -> String { "route.style.color.\(String(rgb, radix: 16))" }
        static let routeEndpointLayer = "route.endpoints"
        static let routeStartPoi = "route.start"
        static let routeEndPoi = "route.end"
        static let routeStartStyle = "route.start.style"
        static let routeEndStyle = "route.end.style"
        static func placeStyle(number: Int, selected: Bool) -> String {
            "place.\(number)\(selected ? ".selected" : "")"
        }
    }

    /// GPS 갱신 간격(약 1초)과 맞춘다. 짧으면 매초 잠깐 멈췄다 가고, 길면 다음 갱신이 중간에 끊는다.
    private static let markerAnimationMillis: UInt = 1_000
    /// 이보다 멀리 뛰면(GPS 재수신, 가상 위치 변경) 지도를 가로질러 미끄러지지 않게 바로 옮긴다.
    private static let markerJumpMeters: CLLocationDistance = 100
    /// 정지 중 이보다 적게 움직이면 GPS 잡음으로 보고 마커를 옮기지 않는다.
    private static let stationaryJitterMeters: CLLocationDistance = 1
    private static let cameraAnimationMillis: UInt = 300
    /// 나침반 값 사이를 잇는 회전 시간. 갱신 간격보다 조금 길게 잡아 끊김 없이 돈다.
    private static let coneRotateMillis: UInt = 150
    private static var isSDKInitialized = false

    private let state: KakaoMapState
    private var controller: KMController?
    private weak var container: KMViewContainer?
    private var shouldBeActive = false

    private var map: KakaoMap? { controller?.getView(ID.mapView) as? KakaoMap }
    /// fitCamera가 SDK 여백(setMargins)을 넣어 둔 상태인지. moveCamera가 있을 때만 비운다.
    private var hasFitMargins = false
    private var myLocationPoi: Poi?
    private var myLocationStyle: String?
    /// 마지막으로 옮긴 내 위치. 다음 위치까지 거리로 애니메이션 여부를 정한다.
    private var myLocationPoint: GeoPoint?
    private var registeredPlaceStyles: Set<String> = []
    private var registeredRouteColors: Set<UInt32> = []
    private var shownPlaceMarkers: [PlaceMarker] = []
    private var shownSelectedPlaceID: String?
    private var placeTapHandlers: [any DisposableEventHandler] = []
    private var cameraStoppedHandler: (any DisposableEventHandler)?
    private var cameraWillMoveHandler: (any DisposableEventHandler)?
    private var followMode = FollowMode.none
    private var routeDrawCount = 0

    /// 마지막으로 적용한 회전값. 359° → 1°처럼 경계를 넘을 때 반대로 한 바퀴 돌지 않게 이어 붙인다.
    private var lastRoll: Double?

    // 정지 중(bearing 없음) 폰이 향한 방향: 따라가기 꺼짐이면 점의 화살촉, 따라가기 중이면 점 아래 콘. 이동 중에는 화살표가 진행 방향을 보여 준다.
    private lazy var compass = CompassHeading { [weak self] in self?.onHeading($0) }
    private var conePoi: Poi?
    private var lastConeRoll: Double?
    /// 나침반이 준 마지막 방향(도, 진북 기준). 아직 모르면 nil.
    private var heading: Double?
    private var isStationary = false

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
        // 백그라운드에서 센서를 계속 켜 두면 배터리를 쓴다.
        if active, myLocationPoi != nil { compass.start() } else { compass.stop() }

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
        compass.stop()
        map?.getTrackingManager().stopTracking()
        conePoi = nil
        disposePlaceTapHandlers()
        cameraStoppedHandler?.dispose()
        cameraStoppedHandler = nil
        cameraWillMoveHandler?.dispose()
        cameraWillMoveHandler = nil
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
        labelManager.addPoiStyle(PoiStyle(styleID: ID.headingDotStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.headingDot()), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.arrowStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.arrow()), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.coneStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.headingCone()), level: 0),
        ]))
    }

    private func configurePlaceLayer(on map: KakaoMap) {
        // 결과끼리 겹쳐도 모두 보이도록 경쟁하지 않는다. 내 위치 레이어보다 아래에 그린다.
        _ = map.getLabelManager().addLabelLayer(option: LabelLayerOptions(
            layerID: ID.placeLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 9_000
        ))
    }

    private func configureRouteLayers(on map: KakaoMap) {
        let routeManager = map.getRouteManager()
        _ = routeManager.addRouteLayer(layerID: ID.routeLayer, zOrder: 8_000)
        // 종류마다 스타일 세트를 따로 두고, 구간 하나를 경로 하나로 그린다.
        let styles: [(RouteLine.Kind, UIColor, UInt)] = [
            (.car, RouteLineColors.car, 8),
            (.walk, RouteLineColors.walk, 5),
            (.bus, RouteLineColors.bus, 8),
            (.subway, RouteLineColors.subway, 8),
        ]
        for (kind, color, width) in styles {
            routeManager.addRouteStyleSet(RouteStyleSet(styleID: ID.routeStyle(kind), styles: [
                RouteStyle(styles: [PerLevelRouteStyle(width: width, color: color, strokeWidth: 2, strokeColor: .white, level: 0)]),
            ]))
        }

        let labelManager = map.getLabelManager()
        _ = labelManager.addLabelLayer(option: LabelLayerOptions(
            layerID: ID.routeEndpointLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 9_500
        ))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.routeStartStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: RouteMarkerImages.start(), anchorPoint: CGPoint(x: 0.5, y: 1)), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.routeEndStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: RouteMarkerImages.end(), anchorPoint: CGPoint(x: 0.5, y: 1)), level: 0),
        ]))
    }

    private func observeCamera(on map: KakaoMap) {
        cameraStoppedHandler = map.addCameraStoppedEventHandler(target: self) { controller in
            { _ in controller.reportCameraCenter() }
        }
        // 코드로 옮긴 카메라(애니메이션·트래킹)는 notUserAction으로 와서 무시된다.
        cameraWillMoveHandler = map.addCameraWillMovedEventHandler(target: self) { controller in
            { param in
                switch param.by {
                case .pan, .longTapAndDrag: controller.state.userDidGesture(.pan)
                case .rotate: controller.state.userDidGesture(.rotate)
                default: break
                }
            }
        }
        reportCameraCenter()
    }

    private func reportCameraCenter() {
        guard let map else { return }
        let rect = map.viewRect
        let coordinate = map.getPosition(CGPoint(x: rect.midX, y: rect.midY)).wgsCoord
        state.cameraDidStop(at: GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude), zoom: map.zoomLevel)
    }

    private func placeStyleID(number: Int, selected: Bool, labelManager: LabelManager) -> String {
        let id = ID.placeStyle(number: number, selected: selected)
        if !registeredPlaceStyles.contains(id) {
            let icon = PoiIconStyle(symbol: PlaceMarkerImages.pin(number: number, selected: selected), anchorPoint: CGPoint(x: 0.5, y: 1))
            labelManager.addPoiStyle(PoiStyle(styleID: id, styles: [PerLevelPoiStyle(iconStyle: icon, level: 0)]))
            registeredPlaceStyles.insert(id)
        }
        return id
    }

    /// 색이 지정된 선(지하철 노선 색)은 그 색의 스타일을 처음 볼 때 등록한다.
    private func routeStyleID(for line: RouteLine, routeManager: RouteManager) -> String {
        guard let rgb = line.rgb else { return ID.routeStyle(line.kind) }
        let id = ID.routeStyle(rgb: rgb)
        if !registeredRouteColors.contains(rgb) {
            routeManager.addRouteStyleSet(RouteStyleSet(styleID: id, styles: [
                RouteStyle(styles: [PerLevelRouteStyle(width: 8, color: UIColor(rgb: rgb), strokeWidth: 2, strokeColor: .white, level: 0)]),
            ]))
            registeredRouteColors.insert(rgb)
        }
        return id
    }

    private func disposePlaceTapHandlers() {
        placeTapHandlers.forEach { $0.dispose() }
        placeTapHandlers.removeAll()
    }

    /// 선택된 마커가 다른 마커에 가려지지 않게 rank를 가장 높게 준다. 번호가 작을수록 위에 그린다.
    private static func placeRank(number: Int, selected: Bool) -> Int {
        selected ? 1_000 : 1_000 - number
    }

    private static func mapPoint(_ point: GeoPoint) -> MapPoint {
        MapPoint(longitude: point.longitude, latitude: point.latitude)
    }

    /// bearing(도, 북쪽 기준 시계방향) → POI roll(라디안).
    /// SDK 문서에 단위·방향이 적혀 있지 않아 실제 화면에서 확인해야 한다.
    private static func roll(fromBearing bearing: Double) -> Double {
        bearing * .pi / 180
    }

    private static func distance(_ a: GeoPoint, _ b: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// 정지 중(점 → 점) GPS 잡음으로 조금 흔들린 위치인가.
    /// 매초 1초짜리 이동 애니메이션을 새로 걸면 지도가 쉬지 않고 다시 그려져(따라가기 중이면 카메라까지) 배터리를 쓴다.
    private func isStationaryJitter(_ location: UserLocation) -> Bool {
        guard let last = myLocationPoint, myLocationPoi != nil, isStationary, location.bearing == nil else { return false }
        return Self.distance(last, location.point) < Self.stationaryJitterMeters
    }

    // MARK: - 따라가기

    /// 모드와 POI 상태에 맞춰 SDK 트래킹을 켜고 끈다. 트래킹은 POI의 이동 애니메이션을 매 프레임 따라가서
    /// 카메라를 따로 움직이는 것보다 마커와 어긋나지 않는다. 회전 모드에서는 POI의 회전값도 따라간다.
    private func syncTracking() {
        guard let tracking = map?.getTrackingManager() else { return }
        // 한 번에 하나만 추적하고, 설정을 바꾸려면 먼저 멈춰야 한다.
        tracking.stopTracking()
        guard followMode != .none, let myLocationPoi else { return }
        tracking.isTrackingRoll = followMode == .followWithHeading
        tracking.startTrackingPoi(myLocationPoi)
    }

    /// 정지 중이면 점 POI를 나침반 방향으로 돌린다. 이동 중에는 화살표가 진행 방향으로 돈다.
    /// - 따라가기 꺼짐: 점의 화살촉이 폰이 향한 방향을 가리킨다.
    /// - 회전 모드: 점은 동그라미라 돌려도 티가 나지 않고, 트래킹이 그 회전을 따라 지도를 돌려서 폰이 향한 방향이 위가 된다.
    private func rotateDotToHeading(duration: UInt = 0) {
        guard isStationary, let heading, let myLocationPoi else { return }
        let roll = continuousRoll(toward: Self.roll(fromBearing: heading))
        myLocationPoi.rotateAt(roll, duration: duration)
        lastRoll = roll
    }

    /// 이동 중이면 화살표. 정지 중이면 따라가기 꺼짐 + 방향을 앎 → 화살촉 달린 점, 그 밖에는 점(따라가기 중엔 콘이 방향을 보여 준다).
    private func myLocationStyleID(bearing: Double?) -> String {
        if bearing != nil { return ID.arrowStyle }
        return heading != nil && followMode == .none ? ID.headingDotStyle : ID.dotStyle
    }

    /// 정지 중 마커 모양을 지금 모드·나침반 상태에 맞춘다. 위치가 그대로여도 모드나 나침반이 바뀌면 불린다.
    private func refreshStationaryMarker() {
        guard isStationary, let myLocationPoi else { return }
        let style = myLocationStyleID(bearing: nil)
        guard style != myLocationStyle else { return }
        myLocationPoi.changeStyle(styleID: style)
        myLocationStyle = style
    }

    // MARK: - 방향 콘

    /// 나침반 값이 바뀔 때(초당 여러 번). 위치 이동과 달리 짧게 돌려서 손을 따라오게 한다.
    private func onHeading(_ degrees: Double) {
        heading = degrees
        refreshStationaryMarker()
        rotateDotToHeading(duration: Self.coneRotateMillis)
        guard let conePoi else { return syncCone(duration: 0) }
        let roll = Self.continuousRoll(toward: Self.roll(fromBearing: degrees), from: lastConeRoll)
        conePoi.rotateAt(roll, duration: Self.coneRotateMillis)
        lastConeRoll = roll
    }

    /// 따라가기 중 정지해 있고 방향을 알면 콘을 내 위치로 옮기고(없으면 만들고), 아니면 지운다.
    private func syncCone(duration: UInt) {
        guard followMode != .none, let point = myLocationPoint, let heading, isStationary,
              let layer = map?.getLabelManager().getLabelLayer(layerID: ID.myLocationLayer) else {
            return removeCone()
        }
        if let conePoi {
            conePoi.moveAt(Self.mapPoint(point), duration: duration)
            return
        }
        let options = PoiOptions(styleID: ID.coneStyle, poiID: ID.conePoi)
        // 점(Int32.max) 바로 아래에 깔린다
        options.rank = Int(Int32.max) - 1
        options.clickable = false
        options.transformType = .absoluteRotation
        guard let poi = layer.addPoi(option: options, at: Self.mapPoint(point)) else { return }
        let roll = Self.roll(fromBearing: heading)
        poi.rotateAt(roll, duration: 0)
        poi.show()
        conePoi = poi
        lastConeRoll = roll
    }

    private func removeCone() {
        if conePoi != nil {
            map?.getLabelManager().getLabelLayer(layerID: ID.myLocationLayer)?.removePoi(poiID: ID.conePoi)
        }
        conePoi = nil
        lastConeRoll = nil
    }

    private func continuousRoll(toward target: Double) -> Double {
        Self.continuousRoll(toward: target, from: lastRoll)
    }

    /// 직전 회전값에서 가까운 쪽으로 target을 이어 붙인다. 359° → 1°는 +2°만 돈다.
    private static func continuousRoll(toward target: Double, from lastRoll: Double?) -> Double {
        guard let lastRoll else { return target }
        var delta = (target - lastRoll).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return lastRoll + delta
    }
}

// MARK: - KakaoMapCommands

extension KakaoMapController: KakaoMapCommands {
    /// fitCamera가 여백을 남겼으면 비워 화면 한가운데 기준으로 되돌린다.
    func moveCamera(to point: GeoPoint, zoom: Int, animated: Bool) {
        guard let map else { return }
        if hasFitMargins {
            map.resetMargins()
            hasFitMargins = false
        }
        let update = CameraUpdate.make(target: Self.mapPoint(point), zoomLevel: zoom, mapView: map)
        if animated {
            map.animateCamera(
                cameraUpdate: update,
                options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
            )
        } else {
            map.moveCamera(update)
        }
    }

    /// 지점이 모두 insets 안쪽(앱 UI에 가리지 않는 영역)에 보이게 맞춘다.
    /// SDK 여백(setMargins)에 UI가 가리는 만큼을 넣으면 영역 맞추기가 그 안쪽 기준이 된다.
    /// 여백은 다음 moveCamera가 비울 때까지 남는다(그동안 내 위치 따라가기도 보이는 영역 기준).
    /// 예전 방식(경로 높이의 고정 배수로 위·아래를 늘림)은 옆으로 긴 경로에서 출발·도착이 탭·시트에 가려졌다.
    func fitCamera(to points: [GeoPoint], insets: MapInsets) {
        guard let map, !points.isEmpty else { return }
        map.setMargins(UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0))
        hasFitMargins = true
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }
        // 보이는 영역 안에서도 가장자리에 붙지 않게(출발·도착 말풍선이 잘리지 않게) 범위를 조금 넓힌다.
        // 한 점이면 최소 범위로 과하게 확대되지 않게 한다.
        let latMargin = max(maxLat - minLat, Self.minFitSpan) * Self.fitEdgeRatio
        let lonMargin = max(maxLon - minLon, Self.minFitSpan) * Self.fitEdgeRatio
        let area = AreaRect(
            southWest: MapPoint(longitude: minLon - lonMargin, latitude: minLat - latMargin),
            northEast: MapPoint(longitude: maxLon + lonMargin, latitude: maxLat + latMargin)
        )
        map.animateCamera(
            cameraUpdate: CameraUpdate.make(area: area, levelLimit: 17),
            options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
        )
    }

    /// 한 점이거나 아주 좁게 모였을 때의 최소 범위(도).
    private static let minFitSpan = 0.002
    /// 범위에 더하는 가장자리 여백 비율.
    private static let fitEdgeRatio = 0.15

    func showPlaceMarkers(_ markers: [PlaceMarker], selectedID: String?) {
        guard let map, let layer = map.getLabelManager().getLabelLayer(layerID: ID.placeLayer) else { return }
        let labelManager = map.getLabelManager()

        // 같은 결과에서 선택만 바뀌었으면 스타일만 바꾼다.
        if markers == shownPlaceMarkers {
            for marker in markers where marker.id == shownSelectedPlaceID || marker.id == selectedID {
                guard let poi = layer.getPoi(poiID: marker.id) else { continue }
                let selected = marker.id == selectedID
                poi.changeStyle(styleID: placeStyleID(number: marker.number, selected: selected, labelManager: labelManager))
                poi.rank = Self.placeRank(number: marker.number, selected: selected)
            }
            shownSelectedPlaceID = selectedID
            return
        }

        disposePlaceTapHandlers()
        layer.clearAllItems()
        for marker in markers {
            let selected = marker.id == selectedID
            let options = PoiOptions(styleID: placeStyleID(number: marker.number, selected: selected, labelManager: labelManager), poiID: marker.id)
            options.rank = Self.placeRank(number: marker.number, selected: selected)
            options.clickable = true
            guard let poi = layer.addPoi(option: options, at: Self.mapPoint(marker.point)) else { continue }
            placeTapHandlers.append(poi.addPoiTappedEventHandler(target: self) { controller in
                { param in controller.state.placeMarkerTapped(id: param.poiItem.itemID) }
            })
            poi.show()
        }
        shownPlaceMarkers = markers
        shownSelectedPlaceID = selectedID
    }

    func showRoute(_ overlay: RouteOverlay?) {
        guard let map,
              let routeLayer = map.getRouteManager().getRouteLayer(layerID: ID.routeLayer),
              let endpointLayer = map.getLabelManager().getLabelLayer(layerID: ID.routeEndpointLayer)
        else { return }

        routeLayer.clearAllRoutes()
        endpointLayer.clearAllItems()
        guard let overlay else { return }

        // 지우기가 비동기라 같은 ID를 바로 다시 쓰면 충돌할 수 있어 그릴 때마다 새 ID를 쓴다.
        routeDrawCount += 1
        for (index, line) in overlay.lines.enumerated() where line.points.count >= 2 {
            let styleID = routeStyleID(for: line, routeManager: map.getRouteManager())
            let options = RouteOptions(routeID: "route.\(routeDrawCount).\(index)", styleID: styleID, zOrder: index)
            options.segments = [RouteSegment(points: line.points.map(Self.mapPoint), styleIndex: 0)]
            routeLayer.addRoute(option: options)?.show()
        }

        for (poiID, styleID, point) in [(ID.routeStartPoi, ID.routeStartStyle, overlay.start), (ID.routeEndPoi, ID.routeEndStyle, overlay.end)] {
            let poiOptions = PoiOptions(styleID: styleID, poiID: poiID)
            poiOptions.rank = 1
            endpointLayer.addPoi(option: poiOptions, at: Self.mapPoint(point))?.show()
        }
    }

    /// 내 위치 점(방향이 있으면 화살표). nil이면 지운다.
    /// 처음엔 POI를 만들고, 이후엔 위치·회전만 애니메이션으로 옮긴다. 100m 넘게 뛰면 바로 옮긴다.
    func updateMyLocation(_ location: UserLocation?) {
        guard let layer = map?.getLabelManager().getLabelLayer(layerID: ID.myLocationLayer) else { return }

        guard let location else {
            map?.getTrackingManager().stopTracking()
            layer.removePoi(poiID: ID.myLocationPoi)
            myLocationPoi = nil
            myLocationStyle = nil
            myLocationPoint = nil
            lastRoll = nil
            compass.stop()
            removeCone()
            return
        }
        if isStationaryJitter(location) { return }

        let point = Self.mapPoint(location.point)
        let style = myLocationStyleID(bearing: location.bearing)
        let isNewPoi = myLocationPoi == nil
        let jumped = myLocationPoint.map { Self.distance($0, location.point) > Self.markerJumpMeters } ?? true
        let duration = jumped ? 0 : Self.markerAnimationMillis

        if let poi = myLocationPoi {
            if style != myLocationStyle {
                poi.changeStyle(styleID: style)
                myLocationStyle = style
            }
            poi.moveAt(point, duration: duration)
            if let bearing = location.bearing {
                let roll = continuousRoll(toward: Self.roll(fromBearing: bearing))
                poi.rotateAt(roll, duration: duration)
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
            // 위치를 받기 전에 따라가기를 켰으면 POI가 생긴 지금 시작한다.
            syncTracking()
        }
        myLocationPoint = location.point
        let wasStationary = isStationary
        isStationary = location.bearing == nil
        // 방금 멈췄거나 처음 그렸으면 점(화살촉)을 지금 방향으로 맞춘다. 나침반은 방향이 바뀔 때만 알려 준다.
        if isStationary, isNewPoi || !wasStationary { rotateDotToHeading() }
        if shouldBeActive { compass.start() }
        // 콘도 점과 같은 시간에 걸쳐 따라간다(멀리 뛰었거나 처음이면 바로).
        syncCone(duration: duration)
    }

    /// 카메라가 내 위치를 따라간다. 회전 모드를 끄면 지도를 다시 북쪽이 위로 돌린다.
    func setFollowMode(_ mode: FollowMode) {
        guard mode != followMode else { return }
        let wasRotating = followMode == .followWithHeading
        followMode = mode
        syncTracking()
        refreshStationaryMarker()
        rotateDotToHeading()
        syncCone(duration: 0)
        if wasRotating, mode != .followWithHeading, let map {
            map.animateCamera(
                cameraUpdate: CameraUpdate.make(rotation: 0, tilt: map.tiltAngle, mapView: map),
                options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
            )
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
        configurePlaceLayer(on: map)
        configureRouteLayers(on: map)
        configureMyLocationLayer(on: map)
        observeCamera(on: map)
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

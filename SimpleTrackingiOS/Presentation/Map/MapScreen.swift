import SwiftUI

struct MapScreen: View {
    let kakaoNativeAppKey: String
    let viewModel: MapViewModel

    @State private var mapState = KakaoMapState()
    @State private var toastMessage: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if kakaoNativeAppKey.isEmpty {
                missingKeyNotice
            } else {
                map
            }
        }
        .toast(message: $toastMessage)
        .alert("permission.alert.title", isPresented: $viewModel.isSettingsAlertPresented) {
            Button("permission.alert.openSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("permission.alert.message")
        }
        .task { await viewModel.onAppear() }
        .task { await consumeEffects() }
        .onChange(of: viewModel.myLocation) { _, location in
            mapState.updateMyLocation(location)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await viewModel.onBecameActive() }
            case .background: viewModel.onEnteredBackground()
            default: break
            }
        }
    }

    private var map: some View {
        ZStack(alignment: .bottomTrailing) {
            KakaoMapView(appKey: kakaoNativeAppKey, state: mapState, isActive: scenePhase == .active)
                .ignoresSafeArea()

            if let failure = mapState.loadFailure {
                Text("map.loadFailed \(failure)")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
            }

            MyLocationButton(hasPermission: viewModel.hasLocationPermission) {
                viewModel.onMyLocationButtonTapped()
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
    }

    private var missingKeyNotice: some View {
        ContentUnavailableView(
            "map.missingKey.title",
            systemImage: "key.slash",
            description: Text("map.missingKey.description")
        )
    }

    private func consumeEffects() async {
        for await effect in viewModel.effects {
            switch effect {
            case let .moveCamera(point, zoom):
                mapState.moveCamera(to: point, zoom: zoom)
            case let .showError(error):
                toastMessage = error.userMessage
            case let .showMessage(message):
                toastMessage = message
            case .requestLocationPermission:
                await viewModel.requestLocationPermission()
            }
        }
    }
}

import Foundation
import Observation

/// 길찾기 출발지·도착지를 고르는 검색(EndpointPickerPage). 지도 검색(PlaceSearchViewModel)과 달리
/// 결과를 지도에 띄우지 않고 페이지 안 목록에서 바로 고른다. 입력 중 실시간 검색은 지도 검색 미리보기와 같은 규칙.
/// 선택 페이지가 떠 있는 동안만 산다.
@MainActor
@Observable
final class EndpointSearchViewModel {
    var query = ""
    private(set) var isSubmitting = false
    /// nil이면 아직 검색하지 않았다(최근 검색어를 보여준다).
    /// 입력 중 새 결과가 올 때까지는 이전 결과를 그대로 둔다(깜빡임 없음).
    private(set) var results: [Place]?
    /// `results`를 찾은 검색어(정리된 형태). 그 목록에서 장소를 고르면 이 검색어를 최근 검색어에 남긴다.
    private(set) var resultsQuery = ""
    /// 마지막으로 찾기로 한 검색어(정리된 형태). 공백만 바뀌어 같으면 다시 찾지 않는다.
    private(set) var searchedFor = ""
    private(set) var recentQueries: [String] = []

    /// 엔터 검색 실패만 알린다(실시간 검색 실패는 조용히 넘긴다).
    let errors: AsyncStream<DomainError>

    @ObservationIgnored private let errorContinuation: AsyncStream<DomainError>.Continuation
    @ObservationIgnored private let searchPlaces: SearchPlacesUseCase
    @ObservationIgnored private let recentSearches: RecentSearchesUseCase
    @ObservationIgnored private let recentPlaces: RecentPlacesUseCase
    @ObservationIgnored private let searchDelay: Duration
    /// 늦게 도착한 이전 검색 결과가 최신 결과를 덮어쓰지 않게 한다(실시간·엔터 검색 공통).
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(
        searchPlaces: SearchPlacesUseCase,
        recentSearches: RecentSearchesUseCase,
        recentPlaces: RecentPlacesUseCase,
        searchDelay: Duration = .milliseconds(300)
    ) {
        self.searchPlaces = searchPlaces
        self.recentSearches = recentSearches
        self.recentPlaces = recentPlaces
        self.searchDelay = searchDelay
        (errors, errorContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        searchTask?.cancel()
        errorContinuation.finish()
    }

    func onAppear() async {
        recentQueries = await recentSearches.list()
    }

    /// 입력칸이 바뀔 때마다(실시간 검색). `center`는 거리 계산 기준(보통 내 위치).
    /// 입력이 `searchDelay` 동안 멈추면 찾는다. 연달아 입력하면 마지막 것만 요청한다.
    /// 입력을 다 지우면 최근 검색어로 돌아간다.
    func onQueryChanged(_ text: String, center: GeoPoint?) {
        query = text
        let normalized = QueryNormalizer.normalize(text)
        guard normalized != searchedFor else { return }
        cancelPending()
        searchedFor = normalized
        guard !normalized.isEmpty else {
            results = nil
            resultsQuery = ""
            return
        }
        let generation = generation
        searchTask = Task { [weak self, searchDelay] in
            try? await Task.sleep(for: searchDelay)
            guard !Task.isCancelled else { return }
            await self?.searchAsYouType(normalized, center: center, generation: generation)
        }
    }

    /// 키보드 엔터. 기다리지 않고 바로 찾고, 실패하면 오류를 보인다.
    func submit(center: GeoPoint?) async {
        cancelPending()
        let generation = generation
        let normalized = QueryNormalizer.normalize(query)
        searchedFor = normalized
        isSubmitting = true
        do {
            let places = try await searchPlaces(query: query, center: center)
            guard generation == self.generation else { return }
            let recents = await recentSearches.add(normalized)
            guard generation == self.generation else { return }
            results = places
            resultsQuery = normalized
            recentQueries = recents
            isSubmitting = false
        } catch {
            guard generation == self.generation else { return }
            isSubmitting = false
            if !(error is CancellationError) {
                errorContinuation.yield(error as? DomainError ?? .unknown)
            }
        }
    }

    /// 최근 검색어 탭.
    func searchRecent(_ recent: String, center: GeoPoint?) async {
        query = recent
        await submit(center: center)
    }

    /// 결과 목록에서 장소 탭. 고른 장소는 최근 장소에, 그 목록을 찾은 검색어는 최근 검색어에 남긴다.
    func remember(_ place: Place) async {
        let keyword = resultsQuery
        await recentPlaces.add(place)
        if !keyword.isEmpty { _ = await recentSearches.add(keyword) }
    }

    /// 최근 검색어 줄의 X.
    func removeRecent(_ recent: String) async {
        recentQueries = await recentSearches.remove(recent)
    }

    /// 테스트 전용: 대기 중인 실시간 검색이 끝날 때까지 기다린다.
    func waitForSearch() async {
        await searchTask?.value
    }

    private func searchAsYouType(_ query: String, center: GeoPoint?, generation: Int) async {
        let places = try? await searchPlaces(query: query, center: center)
        // 그사이 다른 입력·엔터·화면 닫힘이 있었으면 세대가 달라 버린다.
        guard generation == self.generation, let places else { return }
        results = places
        resultsQuery = query
    }

    /// 대기 중인 요청은 보내지 않고, 진행 중인 응답은 버린다.
    private func cancelPending() {
        searchTask?.cancel()
        searchTask = nil
        generation += 1
    }
}

import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class RadioPlayer: ObservableObject {
    @Published private(set) var stations: [Station] = []
    @Published var selectedStationID: Station.ID?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoadingStation = false
    @Published var volume: Float = 1.0 {
        didSet {
            let clamped = min(max(volume, 0), 1)
            if clamped != volume {
                volume = clamped
                return
            }
            player.volume = clamped
            saveVolume()
        }
    }
    @Published private(set) var statusText = L10n.string(L10n.playerStatusStopped)
    @Published private(set) var nowPlayingTitle = L10n.string(L10n.playerUnknownTrack)
    @Published private(set) var nowPlayingArtist = L10n.string(L10n.playerUnknownArtist)
    @Published private(set) var nowPlayingArtwork: NSImage?
    @Published private(set) var trackHistory: [TrackHistoryItem] = []

    private static let maxStations = 15
    private static let maxTrackHistoryCount = 100

    private let volumeStorageKey = "playerVolume"
    private let stationStore: StationStore
    private let stationValidator: StationValidator
    private let metadataResolver: NowPlayingMetadataResolver
    private let artworkService: ArtworkService
    private let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var itemStatusCancellable: AnyCancellable?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private let metadataOutputDelegate = MetadataOutputDelegate()
    private var metadataItemsTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var lastArtworkLookupKey: String?
    private var lastRecordedTrackKey: String?
    private var isCurrentItemReadyToPlay = false

    init(
        stationStore: StationStore,
        stationValidator: StationValidator,
        metadataResolver: NowPlayingMetadataResolver,
        artworkService: ArtworkService
    ) {
        self.stationStore = stationStore
        self.stationValidator = stationValidator
        self.metadataResolver = metadataResolver
        self.artworkService = artworkService
        metadataOutputDelegate.onMetadata = { [weak self] metadataItems in
            self?.applyMetadataItems(metadataItems)
        }
        loadPersistedStations()
        loadPersistedVolume()
        setupObservers()
    }

    convenience init() {
        self.init(
            stationStore: StationStore(),
            stationValidator: StationValidator(),
            metadataResolver: NowPlayingMetadataResolver(),
            artworkService: ArtworkService()
        )
    }

    var selectedStation: Station? {
        guard let selectedStationID else { return nil }
        return stations.first(where: { $0.id == selectedStationID })
    }

    var maxStationsCount: Int { Self.maxStations }
    var canAddStation: Bool { stations.count < Self.maxStations }

    func togglePlayback() {
        if isPlaying || player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            pause()
        } else {
            statusText = L10n.string(L10n.playerStatusStarting)
            playSelectedStation(forceReload: true)
        }
    }

    func selectStation(_ station: Station) {
        selectedStationID = station.id
        saveSelectedStationID()
        statusText = L10n.string(L10n.playerStatusStarting)
        playSelectedStation(forceReload: true)
    }

    func addStation(name: String, urlString: String) -> Bool {
        guard canAddStation else { return false }

        guard let input = stationValidator.validatedInput(name: name, urlString: urlString) else {
            return false
        }

        let station = Station(name: input.name, url: input.url)
        stations.append(station)
        saveStations()
        selectStation(station)
        return true
    }

    func updateStation(_ station: Station, name: String, urlString: String) -> Bool {
        guard let input = stationValidator.validatedInput(name: name, urlString: urlString),
              let index = stations.firstIndex(where: { $0.id == station.id })
        else {
            return false
        }

        stations[index] = Station(id: station.id, name: input.name, url: input.url)
        saveStations()

        if selectedStationID == station.id {
            statusText = L10n.string(L10n.playerStatusStarting)
            playSelectedStation(forceReload: true)
        }

        return true
    }

    func deleteStation(_ station: Station) {
        let wasSelected = station.id == selectedStationID
        stations.removeAll(where: { $0.id == station.id })
        saveStations()

        guard !stations.isEmpty else {
            selectedStationID = nil
            saveSelectedStationID()
            player.pause()
            player.replaceCurrentItem(with: nil)
            isPlaying = false
            statusText = L10n.string(L10n.playerStatusNoStations)
            resetNowPlaying()
            return
        }

        if wasSelected {
            selectedStationID = stations.first?.id
            saveSelectedStationID()
            statusText = L10n.string(L10n.playerStatusStarting)
            playSelectedStation(forceReload: true)
        }
    }

    func restartCurrentStation() {
        statusText = L10n.string(L10n.playerStatusRestarting)
        playSelectedStation(forceReload: true)
    }

    func clearTransientDataOnExit() {
        URLCache.shared.removeAllCachedResponses()
    }

    private func loadPersistedStations() {
        stations = stationStore.loadStations()
        selectedStationID = stationStore.loadSelectedStationID(validStations: stations) ?? stations.first?.id
        saveSelectedStationID()
    }

    private func saveStations() {
        stationStore.saveStations(stations)
    }

    private func saveSelectedStationID() {
        stationStore.saveSelectedStationID(selectedStationID)
    }

    private func loadPersistedVolume() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: volumeStorageKey) != nil {
            volume = defaults.float(forKey: volumeStorageKey)
        } else {
            volume = 1.0
        }
        player.volume = volume
    }

    private func saveVolume() {
        UserDefaults.standard.set(volume, forKey: volumeStorageKey)
    }

    private func setupObservers() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                switch status {
                case .paused:
                    self.isPlaying = false
                    if self.isLoadingStation,
                       self.statusText != L10n.string(L10n.playerStatusStarting),
                       self.statusText != L10n.string(L10n.playerStatusConnecting),
                       self.statusText != L10n.string(L10n.playerStatusBuffering),
                       self.statusText != L10n.string(L10n.playerStatusRestarting) {
                        self.isLoadingStation = false
                    }
                    if self.statusText == L10n.string(L10n.playerStatusBuffering) || self.statusText == L10n.string(L10n.playerStatusPlaying) {
                        self.statusText = L10n.string(L10n.playerStatusPaused)
                    }
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    self.isLoadingStation = true
                    self.statusText = L10n.string(L10n.playerStatusBuffering)
                case .playing:
                    self.isPlaying = true
                    self.isLoadingStation = !self.isCurrentItemReadyToPlay
                    self.statusText = L10n.string(L10n.playerStatusPlaying)
                @unknown default:
                    self.isPlaying = false
                    self.isLoadingStation = false
                    self.statusText = L10n.string(L10n.playerStatusUnknown)
                }
            }
            .store(in: &cancellables)
    }

    private func pause() {
        player.pause()
        isPlaying = false
        isLoadingStation = false
        statusText = L10n.string(L10n.playerStatusPaused)
    }

    private func playSelectedStation(forceReload: Bool) {
        guard let station = selectedStation else { return }

        if !forceReload,
           let currentAsset = player.currentItem?.asset as? AVURLAsset,
           currentAsset.url == station.url {
            isCurrentItemReadyToPlay = true
            isLoadingStation = false
            player.play()
            return
        }

        isCurrentItemReadyToPlay = false
        isLoadingStation = true
        statusText = L10n.string(L10n.playerStatusConnecting)
        resetNowPlaying()

        let item = AVPlayerItem(url: station.url)
        observe(item: item)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func observe(item: AVPlayerItem) {
        if let metadataOutput {
            player.currentItem?.remove(metadataOutput)
        }

        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(metadataOutputDelegate, queue: .main)
        item.add(metadataOutput)
        self.metadataOutput = metadataOutput

        itemStatusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                switch status {
                case .unknown:
                    break
                case .readyToPlay:
                    self.isCurrentItemReadyToPlay = true
                    Task { @MainActor [weak self, asset = item.asset] in
                        guard let self else { return }
                        let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
                        self.applyMetadataItems(commonMetadata)
                    }
                    if self.player.timeControlStatus == .playing {
                        self.isLoadingStation = false
                    }
                    if self.player.timeControlStatus != .playing {
                        self.player.play()
                    }
                case .failed:
                    self.isPlaying = false
                    self.isCurrentItemReadyToPlay = false
                    self.isLoadingStation = false
                    if let error = item.error as NSError? {
                        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotFindHost {
                            let host = item.asset as? AVURLAsset
                            let hostName = host?.url.host ?? "unknown-host"
                            self.statusText = L10n.dnsError(hostName)
                        } else {
                            self.statusText = error.localizedDescription
                        }
                    } else {
                        self.statusText = L10n.string(L10n.playerStatusPlaybackError)
                    }
                @unknown default:
                    self.isPlaying = false
                    self.statusText = L10n.string(L10n.playerStatusPlaybackError)
                }
            }
    }

    private func resetNowPlaying() {
        metadataItemsTask?.cancel()
        artworkLoadTask?.cancel()
        lastArtworkLookupKey = nil
        nowPlayingTitle = L10n.string(L10n.playerUnknownTrack)
        nowPlayingArtist = L10n.string(L10n.playerUnknownArtist)
        nowPlayingArtwork = nil
    }

    private func applyMetadataItems(_ items: [AVMetadataItem]) {
        metadataItemsTask?.cancel()
        metadataItemsTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let resolved = await metadataResolver.resolve(
                from: items,
                currentTitle: nowPlayingTitle,
                currentArtist: nowPlayingArtist,
                unknownTitle: L10n.string(L10n.playerUnknownTrack),
                unknownArtist: L10n.string(L10n.playerUnknownArtist)
            )

            if let title = resolved.title, !title.isEmpty {
                nowPlayingTitle = title
            }

            if let artist = resolved.artist, !artist.isEmpty {
                nowPlayingArtist = artist
            }

            recordTrackHistoryIfNeeded()

            if let detectedArtwork = resolved.artwork {
                self.lastArtworkLookupKey = nil
                self.nowPlayingArtwork = detectedArtwork
            } else if let detectedArtworkURL = resolved.artworkURL {
                self.lastArtworkLookupKey = nil
                self.loadArtwork(from: detectedArtworkURL)
            } else if let searchArtist = resolved.artworkSearchArtist,
                      let searchTitle = resolved.artworkSearchTitle {
                self.loadArtworkFromSearchIfNeeded(artist: searchArtist, title: searchTitle)
            }
        }
    }

    private func loadArtwork(from url: URL) {
        artworkLoadTask?.cancel()
        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let image = try await artworkService.fetchImage(from: url) else {
                    return
                }
                guard !Task.isCancelled,
                      self.lastArtworkLookupKey == nil
                else {
                    return
                }
                self.nowPlayingArtwork = image
            } catch {
                // Keep existing artwork/placeholder when fetch fails.
            }
        }
    }

    private func loadArtworkFromSearchIfNeeded(artist: String, title: String) {
        guard !artist.isEmpty,
              !title.isEmpty,
              artist != L10n.string(L10n.playerUnknownArtist),
              title != L10n.string(L10n.playerUnknownTrack)
        else {
            return
        }

        let lookupKey = "\(artist.lowercased())|\(title.lowercased())"
        guard lookupKey != lastArtworkLookupKey else { return }
        lastArtworkLookupKey = lookupKey

        artworkLoadTask?.cancel()
        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let artworkURL = try await artworkService.searchArtworkURL(artist: artist, title: title) else {
                    return
                }

                guard let image = try await artworkService.fetchImage(from: artworkURL) else {
                    return
                }
                guard !Task.isCancelled,
                      self.lastArtworkLookupKey == lookupKey
                else {
                    return
                }

                self.nowPlayingArtwork = image
            } catch {
                // Keep existing artwork/placeholder when search fails.
            }
        }
    }

    private func recordTrackHistoryIfNeeded() {
        let unknownTitle = L10n.string(L10n.playerUnknownTrack)
        let unknownArtist = L10n.string(L10n.playerUnknownArtist)
        let trimmedTitle = nowPlayingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = nowPlayingArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty,
              !trimmedArtist.isEmpty,
              trimmedTitle != unknownTitle,
              trimmedArtist != unknownArtist,
              let stationName = selectedStation?.name
        else {
            return
        }

        let trackKey = "\(stationName.lowercased())|\(trimmedArtist.lowercased())|\(trimmedTitle.lowercased())"
        guard trackKey != lastRecordedTrackKey else { return }

        lastRecordedTrackKey = trackKey
        trackHistory.insert(
            TrackHistoryItem(
                title: trimmedTitle,
                artist: trimmedArtist,
                stationName: stationName
            ),
            at: 0
        )

        if trackHistory.count > Self.maxTrackHistoryCount {
            trackHistory.removeLast(trackHistory.count - Self.maxTrackHistoryCount)
        }
    }
}

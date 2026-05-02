import AppKit
import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class RadioPlayer {
    private(set) var stations: [Station] = []
    var selectedStationID: Station.ID?
    private(set) var isPlaying = false
    private(set) var isLoadingStation = false
    var volume: Float = 1.0 {
        didSet {
            let clamped = min(max(volume, 0), 1)
            if clamped != volume {
                volume = clamped
                return
            }
            playbackEngine.volume = clamped
            saveVolume()
        }
    }
    private(set) var statusText = L10n.string(L10n.playerStatusStopped)

    private static let maxStations = 15

    private let volumeStorageKey = "playerVolume"
    private let stationStore: StationStore
    private let stationValidator: StationValidator
    private let nowPlayingController: NowPlayingController
    private let playbackEngine: PlaybackEngine
    private var commonMetadataTask: Task<Void, Never>?
    private var isCurrentItemReadyToPlay = false

    init(
        stationStore: StationStore,
        stationValidator: StationValidator,
        metadataResolver: NowPlayingMetadataResolver,
        artworkService: ArtworkService,
        playbackEngine: PlaybackEngine
    ) {
        self.stationStore = stationStore
        self.stationValidator = stationValidator
        self.playbackEngine = playbackEngine
        nowPlayingController = NowPlayingController(
            metadataResolver: metadataResolver,
            artworkService: artworkService,
            unknownTitle: L10n.string(L10n.playerUnknownTrack),
            unknownArtist: L10n.string(L10n.playerUnknownArtist)
        )
        nowPlayingController.currentStationName = { [weak self] in
            self?.selectedStation?.name
        }
        self.playbackEngine.onEvent = { [weak self] event in
            self?.handlePlaybackEvent(event)
        }
        loadPersistedStations()
        loadPersistedVolume()
    }

    convenience init() {
        self.init(
            stationStore: StationStore(),
            stationValidator: StationValidator(),
            metadataResolver: NowPlayingMetadataResolver(),
            artworkService: ArtworkService(),
            playbackEngine: PlaybackEngine()
        )
    }

    var selectedStation: Station? {
        guard let selectedStationID else { return nil }
        return stations.first(where: { $0.id == selectedStationID })
    }

    var maxStationsCount: Int { Self.maxStations }
    var canAddStation: Bool { stations.count < Self.maxStations }
    var nowPlayingTitle: String { nowPlayingController.title }
    var nowPlayingArtist: String { nowPlayingController.artist }
    var nowPlayingArtwork: NSImage? { nowPlayingController.artwork }
    var trackHistory: [TrackHistoryItem] { nowPlayingController.trackHistory }

    func togglePlayback() {
        guard selectedStation != nil else {
            statusText = stations.isEmpty
                ? L10n.string(L10n.playerStatusNoStations)
                : L10n.string(L10n.stationNoneSelected)
            return
        }

        if isPlaying || playbackEngine.timeControlStatus == .waitingToPlayAtSpecifiedRate {
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
            playbackEngine.clearCurrentItem()
            isPlaying = false
            statusText = L10n.string(L10n.playerStatusNoStations)
            nowPlayingController.reset()
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
        guard selectedStation != nil else { return }
        statusText = L10n.string(L10n.playerStatusRestarting)
        playSelectedStation(forceReload: true)
    }

    func clearTransientDataOnExit() {
        URLCache.shared.removeAllCachedResponses()
    }

    func clearTrackHistory() {
        nowPlayingController.clearTrackHistory()
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
        playbackEngine.volume = volume
    }

    private func saveVolume() {
        UserDefaults.standard.set(volume, forKey: volumeStorageKey)
    }

    private func pause() {
        playbackEngine.pause()
        isPlaying = false
        isLoadingStation = false
        statusText = L10n.string(L10n.playerStatusPaused)
    }

    private func playSelectedStation(forceReload: Bool) {
        guard let station = selectedStation else { return }

        if !forceReload,
           playbackEngine.currentAssetURL() == station.url {
            isCurrentItemReadyToPlay = true
            isLoadingStation = false
            playbackEngine.playCurrentItem()
            return
        }

        isCurrentItemReadyToPlay = false
        isLoadingStation = true
        statusText = L10n.string(L10n.playerStatusConnecting)
        nowPlayingController.reset()
        playbackEngine.replaceCurrentItem(with: station.url, stationID: station.id)
    }

    private func handlePlaybackEvent(_ event: PlaybackEngine.Event) {
        switch event {
        case .timeControlPaused:
            isPlaying = false
            if isLoadingStation,
               statusText != L10n.string(L10n.playerStatusStarting),
               statusText != L10n.string(L10n.playerStatusConnecting),
               statusText != L10n.string(L10n.playerStatusBuffering),
               statusText != L10n.string(L10n.playerStatusRestarting) {
                isLoadingStation = false
            }
            if statusText == L10n.string(L10n.playerStatusBuffering) || statusText == L10n.string(L10n.playerStatusPlaying) {
                statusText = L10n.string(L10n.playerStatusPaused)
            }

        case .timeControlWaiting:
            isPlaying = false
            isLoadingStation = true
            statusText = L10n.string(L10n.playerStatusBuffering)

        case .timeControlPlaying:
            isPlaying = true
            isLoadingStation = !isCurrentItemReadyToPlay
            statusText = L10n.string(L10n.playerStatusPlaying)

        case .timeControlUnknown:
            isPlaying = false
            isLoadingStation = false
            statusText = L10n.string(L10n.playerStatusUnknown)

        case let .itemReadyToPlay(asset, stationID):
            isCurrentItemReadyToPlay = true
            commonMetadataTask?.cancel()
            commonMetadataTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
                guard !Task.isCancelled,
                      stationID == self.selectedStationID
                else {
                    return
                }
                self.nowPlayingController.handleMetadataItems(commonMetadata)
            }
            if playbackEngine.timeControlStatus == .playing {
                isLoadingStation = false
            }
            if playbackEngine.timeControlStatus != .playing {
                playbackEngine.playCurrentItem()
            }

        case let .itemFailed(error, asset):
            isPlaying = false
            isCurrentItemReadyToPlay = false
            isLoadingStation = false
            if let error {
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotFindHost {
                    let host = asset as? AVURLAsset
                    let hostName = host?.url.host ?? "unknown-host"
                    statusText = L10n.dnsError(hostName)
                } else {
                    statusText = error.localizedDescription
                }
            } else {
                statusText = L10n.string(L10n.playerStatusPlaybackError)
            }

        case let .metadata(items):
            nowPlayingController.handleMetadataItems(items)
        }
    }
}

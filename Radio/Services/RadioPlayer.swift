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
    @Published private(set) var statusText = Localization.statusStopped
    @Published private(set) var nowPlayingTitle = Localization.unknownTrack
    @Published private(set) var nowPlayingArtist = Localization.unknownArtist
    @Published private(set) var nowPlayingArtwork: NSImage?

    private static let maxStations = 15
    private static let defaultStations: [Station] = [
        Station(name: "Lofi Radio", url: URL(string: "https://play.streamafrica.net/lofiradio")!),
        Station(name: "BBC Radio 1", url: URL(string: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one")!)
    ]

    private let stationsStorageKey = "savedStations"
    private let selectedStationStorageKey = "selectedStationID"
    private let volumeStorageKey = "playerVolume"
    private let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var itemStatusCancellable: AnyCancellable?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private let metadataOutputDelegate = MetadataOutputDelegate()
    private var metadataItemsTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var lastArtworkLookupKey: String?
    private var isCurrentItemReadyToPlay = false

    init() {
        metadataOutputDelegate.onMetadata = { [weak self] metadataItems in
            self?.applyMetadataItems(metadataItems)
        }
        loadPersistedStations()
        loadPersistedVolume()
        setupObservers()
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
            statusText = Localization.statusStarting
            playSelectedStation(forceReload: true)
        }
    }

    func selectStation(_ station: Station) {
        selectedStationID = station.id
        saveSelectedStationID()
        statusText = Localization.statusStarting
        playSelectedStation(forceReload: true)
    }

    func addStation(name: String, urlString: String) -> Bool {
        guard canAddStation else { return false }

        guard let input = validatedStationInput(name: name, urlString: urlString) else {
            return false
        }

        let station = Station(name: input.name, url: input.url)
        stations.append(station)
        saveStations()
        selectStation(station)
        return true
    }

    func updateStation(_ station: Station, name: String, urlString: String) -> Bool {
        guard let input = validatedStationInput(name: name, urlString: urlString),
              let index = stations.firstIndex(where: { $0.id == station.id })
        else {
            return false
        }

        stations[index] = Station(id: station.id, name: input.name, url: input.url)
        saveStations()

        if selectedStationID == station.id {
            statusText = Localization.statusStarting
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
            statusText = Localization.statusNoStations
            resetNowPlaying()
            return
        }

        if wasSelected {
            selectedStationID = stations.first?.id
            saveSelectedStationID()
            statusText = Localization.statusStarting
            playSelectedStation(forceReload: true)
        }
    }

    func restartCurrentStation() {
        statusText = Localization.statusRestarting
        playSelectedStation(forceReload: true)
    }

    func clearTransientDataOnExit() {
        URLCache.shared.removeAllCachedResponses()
    }

    private func validatedStationInput(name: String, urlString: String) -> (name: String, url: URL)? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty,
              let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host,
              !host.isEmpty
        else {
            return nil
        }

        return (trimmedName, url)
    }

    private func loadPersistedStations() {
        let defaults = UserDefaults.standard

        if let savedData = defaults.data(forKey: stationsStorageKey),
           let savedStations = try? JSONDecoder().decode([Station].self, from: savedData),
           !savedStations.isEmpty {
            stations = savedStations
        } else {
            stations = Self.defaultStations
            saveStations()
        }

        if let selectedRaw = defaults.string(forKey: selectedStationStorageKey),
           let selectedUUID = UUID(uuidString: selectedRaw),
           stations.contains(where: { $0.id == selectedUUID }) {
            selectedStationID = selectedUUID
        } else {
            selectedStationID = stations.first?.id
            saveSelectedStationID()
        }
    }

    private func saveStations() {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        UserDefaults.standard.set(data, forKey: stationsStorageKey)
    }

    private func saveSelectedStationID() {
        guard let selectedStationID else {
            UserDefaults.standard.removeObject(forKey: selectedStationStorageKey)
            return
        }

        UserDefaults.standard.set(selectedStationID.uuidString, forKey: selectedStationStorageKey)
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
                       self.statusText != Localization.statusStarting,
                       self.statusText != Localization.statusConnecting,
                       self.statusText != Localization.statusBuffering,
                       self.statusText != Localization.statusRestarting {
                        self.isLoadingStation = false
                    }
                    if self.statusText == Localization.statusBuffering || self.statusText == Localization.statusPlaying {
                        self.statusText = Localization.statusPaused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    self.isLoadingStation = true
                    self.statusText = Localization.statusBuffering
                case .playing:
                    self.isPlaying = true
                    self.isLoadingStation = !self.isCurrentItemReadyToPlay
                    self.statusText = Localization.statusPlaying
                @unknown default:
                    self.isPlaying = false
                    self.isLoadingStation = false
                    self.statusText = Localization.statusUnknown
                }
            }
            .store(in: &cancellables)
    }

    private func pause() {
        player.pause()
        isPlaying = false
        isLoadingStation = false
        statusText = Localization.statusPaused
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
        statusText = Localization.statusConnecting
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
                            self.statusText = Localization.dnsError(hostName)
                        } else {
                            self.statusText = error.localizedDescription
                        }
                    } else {
                        self.statusText = Localization.playbackError
                    }
                @unknown default:
                    self.isPlaying = false
                    self.statusText = Localization.playbackError
                }
            }
    }

    private func resetNowPlaying() {
        metadataItemsTask?.cancel()
        artworkLoadTask?.cancel()
        lastArtworkLookupKey = nil
        nowPlayingTitle = Localization.unknownTrack
        nowPlayingArtist = Localization.unknownArtist
        nowPlayingArtwork = nil
    }

    private func applyMetadataItems(_ items: [AVMetadataItem]) {
        metadataItemsTask?.cancel()
        metadataItemsTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var detectedTitle: String?
            var detectedArtist: String?
            var detectedArtwork: NSImage?
            var detectedArtworkURL: URL?

            for item in items {
                if Task.isCancelled { return }

                let raw = (try? await item.load(.stringValue))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let common = item.commonKey?.rawValue {
                    if common == "title", let raw, !raw.isEmpty {
                        detectedTitle = raw
                    }
                    if common == "artist", let raw, !raw.isEmpty {
                        detectedArtist = raw
                    }
                    if common == "artwork",
                       let data = try? await item.load(.dataValue),
                       let image = NSImage(data: data) {
                        detectedArtwork = image
                    }
                }

                if let raw, !raw.isEmpty {
                    if detectedTitle == nil,
                       let identifier = item.identifier?.rawValue.lowercased(),
                       identifier.contains("title") {
                        detectedTitle = raw
                    }

                    if detectedArtist == nil,
                       let identifier = item.identifier?.rawValue.lowercased(),
                       identifier.contains("artist") {
                        detectedArtist = raw
                    }

                    if raw.contains("text=") || raw.contains("amgArtworkURL=") {
                        let parsed = self.parseIHeartMetadata(raw)
                        if let artist = parsed.artist, !artist.isEmpty {
                            detectedArtist = artist
                        }
                        if let title = parsed.title, !title.isEmpty {
                            detectedTitle = title
                        }
                        if detectedArtworkURL == nil {
                            detectedArtworkURL = parsed.artworkURL
                        }
                    }
                }
            }

            if let title = detectedTitle, detectedArtist == nil, title.contains(" - ") {
                let parts = title.split(separator: "-", maxSplits: 1).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if parts.count == 2 {
                    detectedArtist = parts[0]
                    detectedTitle = parts[1]
                }
            }

            if let detectedTitle, !detectedTitle.isEmpty {
                self.nowPlayingTitle = detectedTitle
            }

            if let detectedArtist, !detectedArtist.isEmpty {
                self.nowPlayingArtist = detectedArtist
            }

            if let detectedArtwork {
                self.lastArtworkLookupKey = nil
                self.nowPlayingArtwork = detectedArtwork
            } else if let detectedArtworkURL {
                self.lastArtworkLookupKey = nil
                self.loadArtwork(from: detectedArtworkURL)
            } else {
                let fallbackTitle = (detectedTitle ?? self.nowPlayingTitle).trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackArtist = (detectedArtist ?? self.nowPlayingArtist).trimmingCharacters(in: .whitespacesAndNewlines)
                self.loadArtworkFromSearchIfNeeded(artist: fallbackArtist, title: fallbackTitle)
            }
        }
    }

    private func parseIHeartMetadata(_ raw: String) -> (artist: String?, title: String?, artworkURL: URL?) {
        var artist: String?
        var title: String?

        if let dashRange = raw.range(of: " - ") {
            artist = String(raw[..<dashRange.lowerBound])
                .replacingOccurrences(of: "StreamTitle='", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " '\t\n\r"))
        }

        title = extractQuotedField("text", from: raw)

        var artworkURL: URL?
        if let urlString = extractQuotedField("amgArtworkURL", from: raw),
           let url = URL(string: urlString),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            artworkURL = url
        }

        return (artist, title, artworkURL)
    }

    private func extractQuotedField(_ key: String, from text: String) -> String? {
        let marker = key + "=\""
        guard let start = text.range(of: marker)?.upperBound,
              let end = text[start...].firstIndex(of: "\"")
        else {
            return nil
        }

        let value = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func loadArtwork(from url: URL) {
        artworkLoadTask?.cancel()
        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      let image = NSImage(data: data)
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
              artist != Localization.unknownArtist,
              title != Localization.unknownTrack
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
                guard let artworkURL = try await fetchArtworkURL(artist: artist, title: title) else {
                    return
                }

                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                guard !Task.isCancelled,
                      self.lastArtworkLookupKey == lookupKey,
                      let image = NSImage(data: data)
                else {
                    return
                }

                self.nowPlayingArtwork = image
            } catch {
                // Keep existing artwork/placeholder when search fails.
            }
        }
    }

    private func fetchArtworkURL(artist: String, title: String) async throws -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

        guard let first = decoded.results.first else { return nil }

        if let original = first.artworkUrl100 ?? first.artworkUrl60 {
            let highRes = original
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "60x60bb", with: "600x600bb")
            return URL(string: highRes)
        }

        return nil
    }
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrackResult]
}

private struct ITunesTrackResult: Decodable {
    let artworkUrl60: String?
    let artworkUrl100: String?
}

private enum Localization {
    static let statusStopped = String(localized: "player.status.stopped")
    static let statusStarting = String(localized: "player.status.starting")
    static let statusNoStations = String(localized: "player.status.no_stations")
    static let statusRestarting = String(localized: "player.status.restarting")
    static let statusConnecting = String(localized: "player.status.connecting")
    static let statusBuffering = String(localized: "player.status.buffering")
    static let statusPlaying = String(localized: "player.status.playing")
    static let statusPaused = String(localized: "player.status.paused")
    static let statusUnknown = String(localized: "player.status.unknown")
    static let playbackError = String(localized: "player.status.playback_error")
    static let unknownTrack = String(localized: "player.unknown_track")
    static let unknownArtist = String(localized: "player.unknown_artist")

    static func dnsError(_ hostName: String) -> String {
        String(format: NSLocalizedString("player.status.dns_error", comment: "DNS resolution failure for the given host"), hostName)
    }
}

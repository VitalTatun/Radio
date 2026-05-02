import AppKit
import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class NowPlayingController {
    private static let maxTrackHistoryCount = 10

    private let metadataResolver: NowPlayingMetadataResolver
    private let artworkService: ArtworkService
    private let unknownTitle: String
    private let unknownArtist: String

    var currentStationName: () -> String? = { nil }

    private(set) var title: String
    private(set) var artist: String
    private(set) var artwork: NSImage?
    private(set) var trackHistory: [TrackHistoryItem] = []

    private var metadataItemsTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var lastArtworkLookupKey: String?
    private var lastRecordedTrackKey: String?
    private var artworkTrackKey: String?

    init(
        metadataResolver: NowPlayingMetadataResolver,
        artworkService: ArtworkService,
        unknownTitle: String,
        unknownArtist: String
    ) {
        self.metadataResolver = metadataResolver
        self.artworkService = artworkService
        self.unknownTitle = unknownTitle
        self.unknownArtist = unknownArtist
        title = unknownTitle
        artist = unknownArtist
    }

    func reset() {
        metadataItemsTask?.cancel()
        artworkLoadTask?.cancel()
        lastArtworkLookupKey = nil
        artworkTrackKey = nil
        title = unknownTitle
        artist = unknownArtist
        artwork = nil
    }

    func clearTrackHistory() {
        trackHistory = []
        lastRecordedTrackKey = nil
    }

    func handleMetadataItems(_ items: [AVMetadataItem]) {
        metadataItemsTask?.cancel()
        metadataItemsTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let resolved = await metadataResolver.resolve(
                from: items,
                currentTitle: title,
                currentArtist: artist,
                unknownTitle: unknownTitle,
                unknownArtist: unknownArtist
            )

            if let resolvedTitle = resolved.title, !resolvedTitle.isEmpty {
                title = resolvedTitle
            }

            if let resolvedArtist = resolved.artist, !resolvedArtist.isEmpty {
                artist = resolvedArtist
            }

            guard let trackKey = currentTrackKey() else {
                return
            }

            if trackKey != lastRecordedTrackKey,
               artworkTrackKey != trackKey {
                artwork = nil
            }

            recordTrackHistoryIfNeeded(trackKey: trackKey)

            if let detectedArtwork = resolved.artwork {
                lastArtworkLookupKey = nil
                applyArtwork(detectedArtwork, toTrackKey: trackKey)
            } else if let detectedArtworkURL = resolved.artworkURL {
                lastArtworkLookupKey = nil
                loadArtwork(from: detectedArtworkURL, forTrackKey: trackKey)
            } else if let searchArtist = resolved.artworkSearchArtist,
                      let searchTitle = resolved.artworkSearchTitle {
                loadArtworkFromSearchIfNeeded(artist: searchArtist, title: searchTitle, forTrackKey: trackKey)
            }
        }
    }

    private func loadArtwork(from url: URL, forTrackKey trackKey: String) {
        artworkLoadTask?.cancel()
        artworkLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let image = try await artworkService.fetchImage(from: url) else {
                    return
                }
                guard !Task.isCancelled,
                      lastArtworkLookupKey == nil,
                      currentTrackKey() == trackKey
                else {
                    return
                }
                applyArtwork(image, toTrackKey: trackKey)
            } catch {
                // Keep existing artwork/placeholder when fetch fails.
            }
        }
    }

    private func loadArtworkFromSearchIfNeeded(artist: String, title: String, forTrackKey trackKey: String) {
        guard !artist.isEmpty,
              !title.isEmpty,
              artist != unknownArtist,
              title != unknownTitle
        else {
            return
        }

        let lookupKey = "\(artist.lowercased())|\(title.lowercased())"
        guard lookupKey != lastArtworkLookupKey else { return }
        lastArtworkLookupKey = lookupKey

        artworkLoadTask?.cancel()
        artworkLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let artworkURL = try await artworkService.searchArtworkURL(artist: artist, title: title) else {
                    return
                }

                guard let image = try await artworkService.fetchImage(from: artworkURL) else {
                    return
                }
                guard !Task.isCancelled,
                      lastArtworkLookupKey == lookupKey,
                      currentTrackKey() == trackKey
                else {
                    return
                }

                applyArtwork(image, toTrackKey: trackKey)
            } catch {
                // Keep existing artwork/placeholder when search fails.
            }
        }
    }

    private func recordTrackHistoryIfNeeded(trackKey: String) {
        guard let stationName = currentStationName() else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trackKey != lastRecordedTrackKey else { return }

        lastRecordedTrackKey = trackKey
        trackHistory.insert(
            TrackHistoryItem(
                trackKey: trackKey,
                title: trimmedTitle,
                artist: trimmedArtist,
                stationName: stationName,
                artworkData: artworkTrackKey == trackKey ? artwork?.tiffRepresentation : nil
            ),
            at: 0
        )

        if trackHistory.count > Self.maxTrackHistoryCount {
            trackHistory.removeLast(trackHistory.count - Self.maxTrackHistoryCount)
        }
    }

    private func currentTrackKey() -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty,
              !trimmedArtist.isEmpty,
              trimmedTitle != unknownTitle,
              trimmedArtist != unknownArtist,
              let stationName = currentStationName()
        else {
            return nil
        }

        return "\(stationName.lowercased())|\(trimmedArtist.lowercased())|\(trimmedTitle.lowercased())"
    }

    private func applyArtwork(_ image: NSImage, toTrackKey trackKey: String) {
        guard let artworkData = image.tiffRepresentation else { return }

        if currentTrackKey() == trackKey {
            artwork = image
            artworkTrackKey = trackKey
        }

        guard let index = trackHistory.firstIndex(where: { $0.trackKey == trackKey }) else { return }

        let item = trackHistory[index]
        trackHistory[index] = TrackHistoryItem(
            id: item.id,
            trackKey: item.trackKey,
            title: item.title,
            artist: item.artist,
            stationName: item.stationName,
            playedAt: item.playedAt,
            artworkData: artworkData
        )
    }
}

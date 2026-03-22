import Foundation

struct TrackHistoryItem: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let stationName: String
    let playedAt: Date
    let artworkData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        stationName: String,
        playedAt: Date = .now,
        artworkData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.stationName = stationName
        self.playedAt = playedAt
        self.artworkData = artworkData
    }
}

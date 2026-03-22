import Foundation

struct TrackHistoryItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let stationName: String
    let playedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        stationName: String,
        playedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.stationName = stationName
        self.playedAt = playedAt
    }
}

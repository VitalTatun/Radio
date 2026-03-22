import AppKit
import Foundation

struct ArtworkService {
    func fetchImage(from url: URL) async throws -> NSImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return NSImage(data: data)
    }

    func searchArtworkURL(artist: String, title: String) async throws -> URL? {
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

import AppKit
import AVFoundation
import Foundation

struct NowPlayingMetadataResolver {
    struct ResolvedMetadata {
        let title: String?
        let artist: String?
        let artwork: NSImage?
        let artworkURL: URL?
        let artworkSearchArtist: String?
        let artworkSearchTitle: String?
    }

    func resolve(
        from items: [AVMetadataItem],
        currentTitle: String,
        currentArtist: String,
        unknownTitle: String,
        unknownArtist: String
    ) async -> ResolvedMetadata {
        var detectedTitle: String?
        var detectedArtist: String?
        var detectedArtwork: NSImage?
        var detectedArtworkURL: URL?

        for item in items {
            if Task.isCancelled {
                return ResolvedMetadata(
                    title: detectedTitle,
                    artist: detectedArtist,
                    artwork: detectedArtwork,
                    artworkURL: detectedArtworkURL,
                    artworkSearchArtist: nil,
                    artworkSearchTitle: nil
                )
            }

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
                    let parsed = parseIHeartMetadata(raw)
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

        let fallbackTitle = (detectedTitle ?? currentTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackArtist = (detectedArtist ?? currentArtist).trimmingCharacters(in: .whitespacesAndNewlines)

        let searchArtist = fallbackArtist.isEmpty || fallbackArtist == unknownArtist ? nil : fallbackArtist
        let searchTitle = fallbackTitle.isEmpty || fallbackTitle == unknownTitle ? nil : fallbackTitle

        return ResolvedMetadata(
            title: detectedTitle,
            artist: detectedArtist,
            artwork: detectedArtwork,
            artworkURL: detectedArtworkURL,
            artworkSearchArtist: searchArtist,
            artworkSearchTitle: searchTitle
        )
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
}

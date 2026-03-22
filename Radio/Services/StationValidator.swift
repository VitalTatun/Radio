import Foundation

struct StationValidator {
    func validatedInput(name: String, urlString: String) -> (name: String, url: URL)? {
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
}

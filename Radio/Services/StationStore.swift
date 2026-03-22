import Foundation

struct StationStore {
    private let defaults: UserDefaults
    private let stationsStorageKey: String
    private let selectedStationStorageKey: String
    private let defaultStations: [Station]

    init(
        defaults: UserDefaults = .standard,
        stationsStorageKey: String = "savedStations",
        selectedStationStorageKey: String = "selectedStationID",
        defaultStations: [Station] = [
            Station(name: "Lofi Radio", url: URL(string: "https://play.streamafrica.net/lofiradio")!),
            Station(name: "BBC Radio 1", url: URL(string: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one")!)
        ]
    ) {
        self.defaults = defaults
        self.stationsStorageKey = stationsStorageKey
        self.selectedStationStorageKey = selectedStationStorageKey
        self.defaultStations = defaultStations
    }

    func loadStations() -> [Station] {
        if let savedData = defaults.data(forKey: stationsStorageKey),
           let savedStations = try? JSONDecoder().decode([Station].self, from: savedData),
           !savedStations.isEmpty {
            return savedStations
        }

        saveStations(defaultStations)
        return defaultStations
    }

    func saveStations(_ stations: [Station]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: stationsStorageKey)
    }

    func loadSelectedStationID(validStations: [Station]) -> Station.ID? {
        guard let selectedRaw = defaults.string(forKey: selectedStationStorageKey),
              let selectedUUID = UUID(uuidString: selectedRaw),
              validStations.contains(where: { $0.id == selectedUUID })
        else {
            return nil
        }

        return selectedUUID
    }

    func saveSelectedStationID(_ stationID: Station.ID?) {
        guard let stationID else {
            defaults.removeObject(forKey: selectedStationStorageKey)
            return
        }

        defaults.set(stationID.uuidString, forKey: selectedStationStorageKey)
    }
}

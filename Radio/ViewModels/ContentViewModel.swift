import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class ContentViewModel {
    struct ScreenState {
        let stationName: String
        let statusText: String
        let isPlaying: Bool
        let canRestartCurrentStation: Bool
        let nowPlayingArtwork: NSImage?
        let nowPlayingTitle: String
        let nowPlayingArtist: String
        let canAddStation: Bool
        let isTrackHistoryEmpty: Bool
        let stations: [Station]
        let selectedStationID: Station.ID?
        let isLoadingStation: Bool
        let trackHistory: [TrackHistoryItem]
    }

    enum ListMode {
        case stations
        case history

        var sectionTitle: LocalizedStringResource {
            switch self {
            case .stations:
                L10n.sectionStations
            case .history:
                L10n.sectionHistory
            }
        }
    }

    var isShowingStationForm = false
    var editingStation: Station?
    var listMode: ListMode = .stations
    var stationName = ""
    var stationURL = ""
    var showValidationError = false
    var hoveredStationID: Station.ID?

    var listSectionTitle: LocalizedStringResource {
        listMode.sectionTitle
    }

    var isShowingStations: Bool {
        listMode == .stations
    }

    var isEditingStation: Bool {
        editingStation != nil
    }

    var shouldShowStationForm: Bool {
        isShowingStationForm && isShowingStations
    }

    func makeScreenState(from radioPlayer: RadioPlayer) -> ScreenState {
        ScreenState(
            stationName: radioPlayer.selectedStation?.name ?? L10n.string(L10n.stationNoneSelected),
            statusText: radioPlayer.statusText,
            isPlaying: radioPlayer.isPlaying,
            canRestartCurrentStation: radioPlayer.selectedStation != nil,
            nowPlayingArtwork: radioPlayer.nowPlayingArtwork,
            nowPlayingTitle: radioPlayer.nowPlayingTitle,
            nowPlayingArtist: radioPlayer.nowPlayingArtist,
            canAddStation: radioPlayer.canAddStation,
            isTrackHistoryEmpty: radioPlayer.trackHistory.isEmpty,
            stations: radioPlayer.stations,
            selectedStationID: radioPlayer.selectedStationID,
            isLoadingStation: radioPlayer.isLoadingStation,
            trackHistory: radioPlayer.trackHistory
        )
    }

    func toggleListMode() {
        listMode = isShowingStations ? .history : .stations
    }

    func beginAddingStation(canAddStation: Bool) {
        guard canAddStation else { return }

        listMode = .stations
        editingStation = nil
        showValidationError = false

        if isShowingStationForm {
            cancelStationForm()
        } else {
            resetStationForm()
            isShowingStationForm = true
        }
    }

    func beginEditingStation(_ station: Station) {
        listMode = .stations
        editingStation = station
        showValidationError = false
        stationName = station.name
        stationURL = station.url.absoluteString
        isShowingStationForm = true
    }

    func cancelStationForm() {
        isShowingStationForm = false
        resetStationForm()
    }

    func canSubmitStationForm(canAddStation: Bool) -> Bool {
        editingStation != nil || canAddStation
    }

    func submitStationForm(using radioPlayer: RadioPlayer) {
        let wasSuccessful: Bool

        if let editingStation {
            wasSuccessful = radioPlayer.updateStation(editingStation, name: stationName, urlString: stationURL)
        } else {
            wasSuccessful = radioPlayer.addStation(name: stationName, urlString: stationURL)
        }

        if wasSuccessful {
            cancelStationForm()
        } else {
            showValidationError = true
        }
    }

    private func resetStationForm() {
        showValidationError = false
        editingStation = nil
        stationName = ""
        stationURL = ""
    }
}

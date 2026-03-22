import SwiftUI

enum L10n {
    static let actionAdd: LocalizedStringResource = "action.add"
    static let actionAddStation: LocalizedStringResource = "action.add_station"
    static let actionCancel: LocalizedStringResource = "action.cancel"
    static let actionDelete: LocalizedStringResource = "action.delete"
    static let actionEdit: LocalizedStringResource = "action.edit"
    static let actionHistory: LocalizedStringResource = "action.history"
    static let actionPause: LocalizedStringResource = "action.pause"
    static let actionPlay: LocalizedStringResource = "action.play"
    static let actionRestartStream: LocalizedStringResource = "action.restart_stream"
    static let actionSave: LocalizedStringResource = "action.save"
    static let menuQuitApplication: LocalizedStringResource = "menu.quit_application"
    static let playerStatusStopped: LocalizedStringResource = "player.status.stopped"
    static let playerStatusStarting: LocalizedStringResource = "player.status.starting"
    static let playerStatusNoStations: LocalizedStringResource = "player.status.no_stations"
    static let playerStatusRestarting: LocalizedStringResource = "player.status.restarting"
    static let playerStatusConnecting: LocalizedStringResource = "player.status.connecting"
    static let playerStatusBuffering: LocalizedStringResource = "player.status.buffering"
    static let playerStatusPlaying: LocalizedStringResource = "player.status.playing"
    static let playerStatusPaused: LocalizedStringResource = "player.status.paused"
    static let playerStatusUnknown: LocalizedStringResource = "player.status.unknown"
    static let playerStatusPlaybackError: LocalizedStringResource = "player.status.playback_error"
    static let playerUnknownTrack: LocalizedStringResource = "player.unknown_track"
    static let playerUnknownArtist: LocalizedStringResource = "player.unknown_artist"
    static let historyEmpty: LocalizedStringResource = "history.empty"
    static let playerVolume: LocalizedStringResource = "player.volume"
    static let sectionHistory: LocalizedStringResource = "section.history"
    static let sectionStations: LocalizedStringResource = "section.stations"
    static let stationNamePlaceholder: LocalizedStringResource = "station.name_placeholder"
    static let stationNoneSelected: LocalizedStringResource = "station.none_selected"
    static let stationValidationError: LocalizedStringResource = "station.validation_error"
    static let stationsEmpty: LocalizedStringResource = "stations.empty"
    static let stationsLimitReached: LocalizedStringResource = "stations.limit_reached"
    static let stationsLimitReachedDetail: LocalizedStringResource = "stations.limit_reached_detail"

    static func string(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    static func dnsError(_ hostName: String) -> String {
        String(format: NSLocalizedString("player.status.dns_error", comment: "DNS resolution failure for the given host"), hostName)
    }
}

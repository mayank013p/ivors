import Foundation
import AppKit
import SwiftUI
import Combine

public struct MediaTrack {
    public var title: String
    public var artist: String
    public var album: String
    public var artwork: NSImage?
    public var isPlaying: Bool
    public var duration: Double
    public var elapsedTime: Double
    public var playerApp: String
}

// MARK: - Dynamic MediaRemote Framework Binding
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void

final class MediaRemoteBridge {
    static let shared = MediaRemoteBridge()

    private var getNowPlayingInfoFunc: MRMediaRemoteGetNowPlayingInfoFunction?
    private var sendCommandFunc: MRMediaRemoteSendCommandFunction?
    private var registerNotificationsFunc: MRMediaRemoteRegisterForNowPlayingNotificationsFunction?

    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) {
            if let getInfoPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                getInfoPtr.withMemoryRebound(to: MRMediaRemoteGetNowPlayingInfoFunction.self, capacity: 1) { _ in }
                getNowPlayingInfoFunc = unsafeBitCast(getInfoPtr, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            }
            if let sendCmdPtr = dlsym(handle, "MRMediaRemoteSendCommand") {
                sendCommandFunc = unsafeBitCast(sendCmdPtr, to: MRMediaRemoteSendCommandFunction.self)
            }
            if let regPtr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
                registerNotificationsFunc = unsafeBitCast(regPtr, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
            }
        }
    }

    func fetchNowPlayingInfo(completion: @escaping ([String: Any]) -> Void) {
        getNowPlayingInfoFunc?(DispatchQueue.main, completion)
    }

    func sendCommand(_ command: Int32) {
        _ = sendCommandFunc?(command, nil)
    }

    func registerForNotifications() {
        registerNotificationsFunc?(DispatchQueue.main)
    }
}

public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()

    @Published public var currentTrack: MediaTrack = MediaTrack(
        title: "No Media Playing",
        artist: "Play audio in Spotify, YouTube or Apple Music",
        album: "",
        artwork: nil,
        isPlaying: false,
        duration: 1,
        elapsedTime: 0,
        playerApp: "System Media"
    )

    private var timer: Timer?
    private var tickTimer: Timer?

    private init() {
        MediaRemoteBridge.shared.registerForNotifications()
        setupNotificationObservers()
        startPolling()
    }

    private func setupNotificationObservers() {
        // MediaRemote notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )

        // Distributed notifications for Spotify & Apple Music
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: NSNotification.Name("com.apple.iTunes.playerInfo"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }

    private var previousTrackTitle: String = ""
    private var isUserInitiatedTrackChange: Bool = false

    @objc public func updateNowPlaying() {
        // 1. Try Spotify Direct AppleScript Query first if Spotify is active
        fetchSpotifyViaAppleScript()

        // 2. Fetch system-wide MediaRemote Now Playing info
        MediaRemoteBridge.shared.fetchNowPlayingInfo { [weak self] info in
            guard let self = self else { return }

            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 1.0
            let elapsedTime = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0

            var artworkImage: NSImage? = nil
            if let imageData = info["kMRMediaRemoteNowPlayingInfoImageData"] as? Data {
                artworkImage = NSImage(data: imageData)
            } else if let imageData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artworkImage = NSImage(data: imageData)
            }

            if !title.isEmpty && (self.currentTrack.playerApp != "Spotify" || !self.currentTrack.isPlaying) {
                DispatchQueue.main.async {
                    let isNewTrack = (title != self.previousTrackTitle) && (rate > 0.0)
                    if isNewTrack {
                        self.previousTrackTitle = title
                        if !self.isUserInitiatedTrackChange {
                            EventBus.shared.post(.trackChanged(title: title, artist: artist.isEmpty ? "System Media" : artist, artwork: artworkImage))
                        }
                        self.isUserInitiatedTrackChange = false
                    }
                    self.currentTrack = MediaTrack(
                        title: title,
                        artist: artist.isEmpty ? "System Media" : artist,
                        album: album,
                        artwork: artworkImage ?? self.currentTrack.artwork,
                        isPlaying: rate > 0.0,
                        duration: max(duration, 1.0),
                        elapsedTime: elapsedTime,
                        playerApp: "MediaRemote"
                    )
                    EventBus.shared.post(.mediaStateChanged)
                }
            }
        }
    }

    private var lastFetchedArtworkUrl: String = ""

    private static let spotifyScriptSource = """
    tell application "Spotify"
        if player state is playing or player state is paused then
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set isPlay to (player state is playing)
            set dur to (duration of current track) / 1000
            set pos to player position
            set artUrl to ""
            try
                set artUrl to artwork url of current track
            end try
            return trackName & "|||" & artistName & "|||" & albumName & "|||" & isPlay & "|||" & dur & "|||" & pos & "|||" & artUrl
        end if
    end tell
    return ""
    """
    private static let compiledSpotifyScript: NSAppleScript? = NSAppleScript(source: spotifyScriptSource)

    private func fetchSpotifyViaAppleScript() {
        // Fast guard check: Only run AppleScript if Spotify app is actively running!
        let spotifyApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        guard let spotifyApp = spotifyApps.first, !spotifyApp.isTerminated else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let script = Self.compiledSpotifyScript else { return }
            var error: NSDictionary?
            let descriptor = script.executeAndReturnError(&error).stringValue
            if let descriptor = descriptor, !descriptor.isEmpty {
                let parts = descriptor.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let title = parts[0]
                    let artist = parts[1]
                    let album = parts[2]
                    let isPlaying = parts[3] == "true"
                    let duration = Double(parts[4]) ?? 1.0
                    let elapsedTime = Double(parts[5]) ?? 0.0
                    let artworkUrl = parts.count >= 7 ? parts[6] : ""

                    DispatchQueue.main.async {
                        let isNewTrack = (title != self.previousTrackTitle) && isPlaying
                        if isNewTrack {
                            self.previousTrackTitle = title
                            if !self.isUserInitiatedTrackChange {
                                EventBus.shared.post(.trackChanged(title: title, artist: artist, artwork: self.currentTrack.artwork))
                            }
                            self.isUserInitiatedTrackChange = false
                        }
                        self.currentTrack = MediaTrack(
                            title: title,
                            artist: artist,
                            album: album,
                            artwork: self.currentTrack.artwork,
                            isPlaying: isPlaying,
                            duration: max(duration, 1.0),
                            elapsedTime: elapsedTime,
                            playerApp: "Spotify"
                        )
                        EventBus.shared.post(.mediaStateChanged)

                        // Asynchronously download Spotify album cover artwork image
                        if !artworkUrl.isEmpty && artworkUrl != self.lastFetchedArtworkUrl, let url = URL(string: artworkUrl) {
                            self.lastFetchedArtworkUrl = artworkUrl
                            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                                guard let self = self, let data = data, let image = NSImage(data: data) else { return }
                                DispatchQueue.main.async {
                                    self.currentTrack.artwork = image
                                    EventBus.shared.post(.mediaStateChanged)
                                }
                            }.resume()
                        }
                    }
                }
            }
        }
    }

    public func togglePlayPause() {
        isUserInitiatedTrackChange = true
        currentTrack.isPlaying.toggle()
        if currentTrack.playerApp == "Spotify" {
            executeAppleScript("tell application \"Spotify\" to playpause")
        } else {
            MediaRemoteBridge.shared.sendCommand(2)
        }
    }

    public func nextTrack() {
        isUserInitiatedTrackChange = true
        if currentTrack.playerApp == "Spotify" {
            executeAppleScript("tell application \"Spotify\" to next track")
        } else {
            MediaRemoteBridge.shared.sendCommand(4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateNowPlaying()
        }
    }

    public func previousTrack() {
        isUserInitiatedTrackChange = true
        if currentTrack.playerApp == "Spotify" {
            executeAppleScript("tell application \"Spotify\" to previous track")
        } else {
            MediaRemoteBridge.shared.sendCommand(5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateNowPlaying()
        }
    }

    public func seek(to time: Double) {
        let targetTime = max(0, min(currentTrack.duration, time))
        currentTrack.elapsedTime = targetTime
        if currentTrack.playerApp == "Spotify" {
            executeAppleScript("tell application \"Spotify\" to set player position to \(targetTime)")
        } else if currentTrack.playerApp == "Music" || currentTrack.playerApp == "Apple Music" {
            executeAppleScript("tell application \"Music\" to set player position to \(targetTime)")
        }
    }

    private func executeAppleScript(_ scriptString: String) {
        let spotifyApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        guard let spotifyApp = spotifyApps.first, !spotifyApp.isTerminated else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: scriptString) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }

    private func startPolling() {
        updateNowPlaying()
        // 1. AppleScript / MediaRemote query every 1.0s (reduced from 3.0s for instant sync)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }

        // 2. High-precision 0.1s tick timer for live 0-lag time progression & instant lyrics sync
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.currentTrack.isPlaying else { return }
            let nextTime = self.currentTrack.elapsedTime + 0.1
            if nextTime <= self.currentTrack.duration {
                self.currentTrack.elapsedTime = nextTime
            }
        }
    }
}

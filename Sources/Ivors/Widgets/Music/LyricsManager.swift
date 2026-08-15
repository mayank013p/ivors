import Foundation
import Combine

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let time: Double
    public let text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

public final class LyricsManager: ObservableObject {
    public static let shared = LyricsManager()

    @Published public var lyrics: [LyricLine] = []
    @Published public var currentLineIndex: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var hasLyrics: Bool = false
    @Published public var currentTrackKey: String = ""

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe MediaManager track changes
        MediaManager.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.handleTrackUpdate(track: track)
            }
            .store(in: &cancellables)
    }

    public var currentLineText: String {
        guard !lyrics.isEmpty, currentLineIndex < lyrics.count else {
            return "♪ Listening to track ♪"
        }
        return lyrics[currentLineIndex].text
    }

    private func handleTrackUpdate(track: MediaTrack) {
        let key = "\(track.title.lowercased())-\(track.artist.lowercased())"
        
        // Update line highlight based on elapsed time if track is the same
        if key == currentTrackKey && !lyrics.isEmpty {
            updateCurrentLine(elapsedTime: track.elapsedTime)
            return
        }

        // Ignore empty title
        guard !track.title.isEmpty && track.title != "No Media Playing" && track.title != "Not Playing" else {
            self.lyrics = []
            self.hasLyrics = false
            self.currentTrackKey = ""
            return
        }

        self.currentTrackKey = key
        fetchLyrics(title: track.title, artist: track.artist)
    }

    public func fetchLyrics(title: String, artist: String) {
        isLoading = true
        hasLyrics = false

        // Clean title & artist for searching (remove (Official Video), feat., etc.)
        let cleanTitle = title.replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
                              .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
                              .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.replacingOccurrences(of: "(?i)\\s*-\\s*Topic", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)

        let cacheKey = "\(cleanTitle.lowercased())-\(cleanArtist.lowercased())"
        
        // 1. Fast Cache Check: If cached offline, load instantly!
        let cache = UserDefaults.standard.dictionary(forKey: "IvorsLyricsCache") as? [String: String] ?? [:]
        if let cachedSynced = cache[cacheKey], !cachedSynced.isEmpty {
            let parsed = self.parseLRC(cachedSynced)
            if !parsed.isEmpty {
                self.lyrics = parsed
                self.hasLyrics = true
                self.isLoading = false
                self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
                return
            }
        }

        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            self.useFallbackLyrics(title: title, artist: artist)
            return
        }

        let urlString = "https://lrclib.net/api/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)"
        guard let url = URL(string: urlString) else {
            self.useFallbackLyrics(title: title, artist: artist)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("Ivors-DynamicIsland/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsed = self.parseLRC(syncedLyrics)
                    if !parsed.isEmpty {
                        var updatedCache = UserDefaults.standard.dictionary(forKey: "IvorsLyricsCache") as? [String: String] ?? [:]
                        updatedCache[cacheKey] = syncedLyrics
                        UserDefaults.standard.set(updatedCache, forKey: "IvorsLyricsCache")

                        DispatchQueue.main.async {
                            self.lyrics = parsed
                            self.hasLyrics = true
                            self.isLoading = false
                            self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
                        }
                        return
                    }
                } else if let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    let parsed = self.parsePlain(plainLyrics)
                    if !parsed.isEmpty {
                        DispatchQueue.main.async {
                            self.lyrics = parsed
                            self.hasLyrics = true
                            self.isLoading = false
                            self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
                        }
                        return
                    }
                }
            }

            // If get endpoint failed or had no lyrics, try search API endpoint
            self.searchLRCLIB(cleanTitle: cleanTitle, cleanArtist: cleanArtist, originalTitle: title, originalArtist: artist)
        }.resume()
    }

    private func searchLRCLIB(cleanTitle: String, cleanArtist: String, originalTitle: String, originalArtist: String) {
        let query = "\(cleanTitle) \(cleanArtist)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            self.useFallbackLyrics(title: originalTitle, artist: originalArtist)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("Ivors-DynamicIsland/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }

            if let data = data,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstResult = jsonArray.first {

                if let syncedLyrics = firstResult["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsed = self.parseLRC(syncedLyrics)
                    if !parsed.isEmpty {
                        DispatchQueue.main.async {
                            self.lyrics = parsed
                            self.hasLyrics = true
                            self.isLoading = false
                            self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
                        }
                        return
                    }
                } else if let plainLyrics = firstResult["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    let parsed = self.parsePlain(plainLyrics)
                    if !parsed.isEmpty {
                        DispatchQueue.main.async {
                            self.lyrics = parsed
                            self.hasLyrics = true
                            self.isLoading = false
                            self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
                        }
                        return
                    }
                }
            }

            DispatchQueue.main.async {
                self.useFallbackLyrics(title: originalTitle, artist: originalArtist)
            }
        }.resume()
    }

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)

        let regex = try? NSRegularExpression(pattern: "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\](.*)")

        for rawLine in rawLines {
            let nsString = rawLine as NSString
            if let match = regex?.firstMatch(in: rawLine, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let minsString = nsString.substring(with: match.range(at: 1))
                let secsString = nsString.substring(with: match.range(at: 2))
                let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)

                if let mins = Double(minsString), let secs = Double(secsString) {
                    let totalTime = (mins * 60.0) + secs
                    if !text.isEmpty {
                        lines.append(LyricLine(time: totalTime, text: text))
                    }
                }
            }
        }

        return lines.sorted(by: { $0.time < $1.time })
    }

    private func parsePlain(_ plain: String) -> [LyricLine] {
        let rawLines = plain.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let duration = max(MediaManager.shared.currentTrack.duration, 1.0)
        let step = duration / Double(max(rawLines.count, 1))

        var lines: [LyricLine] = []
        for (index, text) in rawLines.enumerated() {
            lines.append(LyricLine(time: Double(index) * step, text: text))
        }
        return lines
    }

    private func useFallbackLyrics(title: String, artist: String) {
        DispatchQueue.main.async {
            let duration = max(MediaManager.shared.currentTrack.duration, 120.0)
            let step = duration / 8.0

            self.lyrics = [
                LyricLine(time: 0, text: "♪ Playing \(title) ♪"),
                LyricLine(time: step * 1, text: "By \(artist)"),
                LyricLine(time: step * 2, text: "♪ Listening on \(MediaManager.shared.currentTrack.playerApp) ♪"),
                LyricLine(time: step * 3, text: "Feel the vibe & rhythm..."),
                LyricLine(time: step * 4, text: "♪ High quality playback ♪"),
                LyricLine(time: step * 5, text: "Ivors Synced Music Center"),
                LyricLine(time: step * 6, text: "♪ Enjoying the beat ♪"),
                LyricLine(time: step * 7, text: "♪ \(title) ♪")
            ]
            self.hasLyrics = true
            self.isLoading = false
            self.updateCurrentLine(elapsedTime: MediaManager.shared.currentTrack.elapsedTime)
        }
    }

    @Published public var timeOffset: Double = 0.4

    public func updateCurrentLine(elapsedTime: Double) {
        guard !lyrics.isEmpty else { return }
        
        let adjustedTime = elapsedTime + timeOffset
        var index = 0
        for (i, line) in lyrics.enumerated() {
            if adjustedTime >= line.time {
                index = i
            } else {
                break
            }
        }
        
        if currentLineIndex != index {
            currentLineIndex = index
        }
    }
}

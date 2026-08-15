import SwiftUI
import Combine

public final class MusicWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "music"
    public let name: String = "Now Playing"
    public let priority: Int = 100
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 240 }
    public var preferredExpandedSize: CGSize { CGSize(width: 350, height: 195) }

    @ObservedObject private var mediaManager = MediaManager.shared

    public init() {}

    public func compactView() -> AnyView {
        AnyView(CompactMusicView(track: mediaManager.currentTrack))
    }

    public func expandedView() -> AnyView {
        AnyView(ExpandedMusicView(mediaManager: mediaManager))
    }

    public func minimalView() -> AnyView {
        AnyView(MinimalMusicView(isPlaying: mediaManager.currentTrack.isPlaying))
    }
}

// MARK: - Compact View
struct CompactMusicView: View {
    let track: MediaTrack

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if let art = track.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .cornerRadius(5)
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text(track.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Expanded View with Big Artwork & Live Lyrics Toggle
struct ExpandedMusicView: View {
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var settings = SettingsManager.shared

    @State private var showLyrics: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Main Track Header Row
            HStack(spacing: 12) {
                // Big Artwork Badge
                ZStack {
                    if let art = mediaManager.currentTrack.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 58, height: 58)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [settings.accentColor.opacity(0.9), Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 58, height: 58)

                if showLyrics {
                    // Synced Lyrics Mini Display
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(settings.accentColor)
                            Text("Synced Lyrics")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(settings.accentColor)
                        }
                        
                        Text(lyricsManager.currentLineText)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    // Track Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mediaManager.currentTrack.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(mediaManager.currentTrack.artist)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                        if !mediaManager.currentTrack.album.isEmpty {
                            Text(mediaManager.currentTrack.album)
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 4)

                // Animated Equalizer Status Badge
                AudioEqualizerView(isPlaying: mediaManager.currentTrack.isPlaying)
                    .frame(width: 16, height: 14)
            }

            // Progress Timeline Slider
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 3.5)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(mediaManager.currentTrack.elapsedTime / max(mediaManager.currentTrack.duration, 1.0)))), height: 3.5)
                    }
                }
                .frame(height: 3.5)

                HStack {
                    Text(formatTime(mediaManager.currentTrack.elapsedTime))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("-\(formatTime(max(0, mediaManager.currentTrack.duration - mediaManager.currentTrack.elapsedTime)))")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Transport Controls & Lyrics Toggle (Crisp, High-Contrast UI Buttons)
            HStack(spacing: 24) {
                // Previous Track Button
                Button(action: { mediaManager.previousTrack() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                // Play / Pause Button (Crisp White Circle with Black Icon for High Contrast!)
                Button(action: { mediaManager.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                        Image(systemName: mediaManager.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: mediaManager.currentTrack.isPlaying ? 0 : 1)
                    }
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                // Next Track Button
                Button(action: { mediaManager.nextTrack() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                // Lyrics Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showLyrics.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(showLyrics ? settings.accentColor.opacity(0.4) : Color.white.opacity(0.14))
                            .overlay(Circle().stroke(showLyrics ? settings.accentColor : Color.clear, lineWidth: 1))
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(showLyrics ? .white : .white.opacity(0.8))
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("Toggle Synced Lyrics")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Minimal View
struct MinimalMusicView: View {
    let isPlaying: Bool

    var body: some View {
        AudioEqualizerView(isPlaying: isPlaying)
            .frame(width: 14, height: 12)
            .padding(6)
    }
}

// MARK: - Animated Equalizer
struct AudioEqualizerView: View {
    let isPlaying: Bool

    @State private var bar1: CGFloat = 0.4
    @State private var bar2: CGFloat = 0.8
    @State private var bar3: CGFloat = 0.5
    @State private var bar4: CGFloat = 0.9

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Capsule().fill(Color.green).frame(width: 2.5, height: isPlaying ? bar1 * 14 : 3)
            Capsule().fill(Color.green).frame(width: 2.5, height: isPlaying ? bar2 * 14 : 5)
            Capsule().fill(Color.green).frame(width: 2.5, height: isPlaying ? bar3 * 14 : 8)
            Capsule().fill(Color.green).frame(width: 2.5, height: isPlaying ? bar4 * 14 : 4)
        }
        .onAppear {
            guard isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                bar1 = 0.9; bar2 = 0.3; bar3 = 0.95; bar4 = 0.4
            }
        }
    }
}

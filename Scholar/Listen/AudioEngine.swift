//
//  AudioEngine.swift
//  Scholar
//
//  A single AVPlayer shared by the podcast feed and the mini player, wired to
//  the lock screen and Control Center.
//

import AVFoundation
import Combine
import MediaPlayer
import Observation
import UIKit

@MainActor
@Observable
final class AudioEngine {
    static let shared = AudioEngine()

    private(set) var current: PodcastEpisode?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isBuffering = false

    /// Set when the user explicitly keeps an episode running while they browse.
    var isPinned = false

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    private init() {
        player.automaticallyWaitsToMinimizeStalling = true
        observeTime()
        configureRemoteCommands()
    }

    // MARK: - Session

    /// `.playback` keeps audio alive under the silent switch and in the
    /// background. The shorts feed relies on it too, since WKWebView audio
    /// follows the app-wide session.
    static func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    // MARK: - Transport

    func play(_ episode: PodcastEpisode) {
        if current?.id == episode.id {
            resume()
            return
        }
        current = episode
        currentTime = 0
        duration = episode.duration
        isBuffering = true

        let item = AVPlayerItem(url: episode.audioURL)
        player.replaceCurrentItem(with: item)

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.handleEnd() }
        }

        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func resume() {
        guard current != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func toggle() { isPlaying ? pause() : resume() }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        isPlaying = false
        isPinned = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to seconds: TimeInterval) {
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlaying()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: min(max(0, currentTime + seconds), max(0, duration)))
    }

    private func handleEnd() {
        isPlaying = false
        currentTime = duration
    }

    // MARK: - Observation

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.isBuffering = self.player.currentItem?.isPlaybackLikelyToKeepUp == false
            }
        }
    }

    // MARK: - Now Playing

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 30) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let episode = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.showTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if let url = episode.artworkURL {
            Task.detached { [weak self] in
                guard let self else { return }
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    guard self.current?.id == episode.id else { return }
                    var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                }
            }
        }
    }
}

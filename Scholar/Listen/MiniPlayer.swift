//
//  MiniPlayer.swift
//  Scholar
//
//  Sits above the tab bar whenever an episode has been pinned to keep playing
//  while the user browses elsewhere.
//

import SwiftUI

struct MiniPlayer: View {
    @State private var audio = AudioEngine.shared

    var body: some View {
        if let episode = audio.current, audio.isPinned {
            HStack(spacing: 10) {
                RemoteImage(url: episode.artworkURL)
                    .frame(width: 38, height: 38)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(episode.showTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button { audio.toggle() } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Button { audio.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .overlay(alignment: .bottom) {
                ProgressBar(value: audio.progress, tint: Theme.accentSoft, height: 2)
                    .padding(.horizontal, 12)
                    .offset(y: -3)
            }
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

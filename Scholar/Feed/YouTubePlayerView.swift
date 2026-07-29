//
//  YouTubePlayerView.swift
//  Scholar
//
//  Playback goes through YouTube's own embed page, so view counts, ads and
//  creator revenue all stay intact — the app never touches the underlying
//  media stream.
//
//  The web view loads a host page from LocalPlayerServer over loopback HTTP,
//  and that page embeds the real youtube.com player in an iframe via the
//  official IFrame Player API.
//
//  That indirection is the whole point, and two earlier designs failed without
//  it. A synthesised document handed to `loadSimulatedRequest` has an opaque
//  origin, which the player rejects with error 152. Navigating straight to
//  `youtube.com/embed/<id>` gives the player no host page at all — no referrer,
//  no ancestor origin — and it refuses with error 153, "video player
//  configuration error". The /embed/ endpoint is built to be framed, not
//  visited. A loopback origin is a real origin, so it satisfies both checks.
//
//  Two further things are load-bearing for playback actually starting:
//
//  1. The clip always starts muted. YouTube's player runs its own mobile
//     autoplay check and silently refuses to begin unmuted without a gesture —
//     it does not error, it just never starts. Sound is restored from here once
//     the player reports PLAYING, and the page puts it back to muted if the
//     unmute suspends playback.
//  2. `.playback` must already be the audio session category — see ScholarApp.
//
//  Contrary to an earlier note in this file, YouTube plays fine in the iOS
//  Simulator: a normal watch page plays there. Only the bare /embed/ URL fails,
//  for the reason above.
//

import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    var isActive: Bool
    var isMuted: Bool
    var onStateChange: (PlayerState) -> Void = { _ in }
    /// Fires when the embed refuses to play — either an uploader who has
    /// blocked off-site playback, or an environment the player rejects.
    var onError: (Int) -> Void = { _ in }

    enum PlayerState: Int {
        case unstarted = -1, ended = 0, playing = 1, paused = 2, buffering = 3, cued = 5
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        // No injected script any more: the bridge is part of the host page the
        // local server serves, alongside the IFrame API it drives.
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "player")

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Let the enclosing SwiftUI ScrollView own vertical gestures.
        webView.scrollView.panGestureRecognizer.isEnabled = false
        // No user-agent override: the embed now sits in a normal page on a
        // normal origin, which is the situation YouTube already serves well.
        // Claiming to be a different iOS version than the one running only
        // added a variable.
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        // Lets you attach Safari's Web Inspector to a card on a real device,
        // which is the only way to see what the embed page is complaining about.
        webView.isInspectable = true
        #endif

        context.coordinator.webView = webView
        context.coordinator.load(videoID: videoID, autoplay: isActive, muted: isMuted)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        // SwiftUI rebuilds this struct with fresh closures on every change, but
        // the coordinator is created once. Without this the player would keep
        // calling back into the very first body's captured state.
        coordinator.onStateChange = onStateChange
        coordinator.onError = onError

        if coordinator.videoID != videoID {
            coordinator.load(videoID: videoID, autoplay: isActive, muted: isMuted)
            return
        }
        coordinator.setMuted(isMuted)
        coordinator.setPlaying(isActive)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        /// Worth one more load: a stalled page, a failed navigation, a script
        /// that never arrived, a player that built but never started, or the
        /// local server not being up yet. YouTube's own verdicts — embedding
        /// disabled (101/150), video gone (100), bad parameter (2) — are not.
        private static let retryableErrors: Set<Int> = [-2, -3, -4, -7, -8, 5]

        weak var webView: WKWebView?
        private(set) var videoID: String?
        private var isReady = false
        private var wantsPlaying = false
        private var wantsMuted = false
        private var hasRetried = false
        private var watchdog: Task<Void, Never>?
        var onStateChange: (PlayerState) -> Void
        var onError: (Int) -> Void

        init(onStateChange: @escaping (PlayerState) -> Void,
             onError: @escaping (Int) -> Void) {
            self.onStateChange = onStateChange
            self.onError = onError
        }

        func load(videoID: String, autoplay: Bool, muted: Bool) {
            self.videoID = videoID
            self.wantsPlaying = autoplay
            self.wantsMuted = muted
            self.hasRetried = false
            start()
        }

        /// Loads the loopback host page, which builds the real youtube.com
        /// embed inside an iframe. See LocalPlayerServer for why the page can't
        /// simply be the embed URL, or a synthesised document.
        private func start() {
            guard let videoID else { return }
            isReady = false

            watchdog?.cancel()
            watchdog = Task { [weak self] in
                guard let port = await LocalPlayerServer.shared.ensureRunning() else {
                    self?.fail(code: -8)
                    return
                }
                guard !Task.isCancelled, let self, let videoID = self.videoID else { return }

                var components = URLComponents()
                components.scheme = "http"
                components.host = "127.0.0.1"
                components.port = Int(port)
                components.path = "/player"
                components.queryItems = [
                    URLQueryItem(name: "v", value: videoID),
                    URLQueryItem(name: "autoplay", value: self.wantsPlaying ? "1" : "0"),
                ]
                guard let url = components.url else { return }

                #if DEBUG
                print("[ScholarPlayer] loading \(url.absoluteString)")
                #endif
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                self.webView?.load(request)

                // If the page never reports in, the card is stuck on black;
                // treat the silence as a failure so the still takes over.
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, !self.isReady else { return }
                self.fail(code: -2)
            }
        }

        /// One retry on the alternate host, then the card falls back.
        private func fail(code: Int) {
            watchdog?.cancel()
            #if DEBUG
            print("[ScholarPlayer] \(videoID ?? "?") error \(code), retried: \(hasRetried)")
            #endif
            guard !hasRetried, Self.retryableErrors.contains(code) else {
                onError(code)
                return
            }
            hasRetried = true
            start()
        }

        func setPlaying(_ playing: Bool) {
            guard wantsPlaying != playing else { return }
            wantsPlaying = playing
            guard isReady else { return }
            webView?.evaluateJavaScript(playing ? "scholarPlay();" : "scholarPause();")
        }

        func setMuted(_ muted: Bool) {
            guard wantsMuted != muted else { return }
            wantsMuted = muted
            guard isReady else { return }
            webView?.evaluateJavaScript("scholarMute(\(muted));")
        }

        func teardown() {
            watchdog?.cancel()
            webView?.evaluateJavaScript("scholarPause();")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "player")
            webView?.configuration.userContentController.removeAllUserScripts()
            webView?.navigationDelegate = nil
            webView?.stopLoading()
            webView = nil
        }

        // MARK: Navigation

        /// The card is a player, not a browser: a tap-through to the watch page
        /// would strand the user inside a feed cell. Only the top-level
        /// document is policed — the embed builds itself out of subframes on
        /// other Google hosts, and refusing those breaks playback outright.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let frame = navigationAction.targetFrame else {
                decisionHandler(.cancel)     // a window.open, never wanted here
                return
            }
            guard frame.isMainFrame else {
                decisionHandler(.allow)
                return
            }
            // The main frame is only ever the loopback host page; the embed
            // itself lives in a subframe, allowed above. Anything else at the
            // top level is a tap-through to the watch page.
            let host = navigationAction.request.url?.host ?? ""
            let isHostPage = host == "127.0.0.1" || host == "localhost"
            decisionHandler(navigationAction.navigationType == .other && isHostPage ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logNavigationFailure(error)
            fail(code: -3)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            logNavigationFailure(error)
            fail(code: -3)
        }

        private func logNavigationFailure(_ error: Error) {
            #if DEBUG
            let ns = error as NSError
            print("[ScholarPlayer] navigation failed: \(ns.domain) \(ns.code) — \(ns.localizedDescription)")
            #endif
        }

        // MARK: Bridge

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "ready":
                isReady = true
                watchdog?.cancel()
                webView?.evaluateJavaScript(wantsPlaying ? "scholarPlay();" : "scholarPause();")
            case "state":
                guard let raw = body["state"] as? Int, let state = PlayerState(rawValue: raw) else { return }
                // Only safe to ask for sound once it is actually running; the
                // bridge reverts to muted if the unmute suspends playback.
                if state == .playing, !wantsMuted {
                    webView?.evaluateJavaScript("scholarMute(false);")
                }
                onStateChange(state)
            case "mutedfallback":
                #if DEBUG
                print("[ScholarPlayer] \(videoID ?? "?") play refused with sound; fell back to muted")
                #endif
            case "error":
                #if DEBUG
                if let detail = body["detail"] as? String, !detail.isEmpty {
                    print("[ScholarPlayer] page said: \(detail.replacingOccurrences(of: "\n", with: " / "))")
                }
                #endif
                fail(code: body["code"] as? Int ?? -1)
            default:
                break
            }
        }

    }
}

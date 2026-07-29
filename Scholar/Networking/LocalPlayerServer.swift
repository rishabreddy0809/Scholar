//
//  LocalPlayerServer.swift
//  Scholar
//
//  Serves the player's host page over loopback HTTP.
//
//  YouTube's /embed/ endpoint is built to be loaded *inside* a page. Opened as
//  a top-level document it has no referrer and no ancestor origin, and the
//  player refuses to configure — "Error 153: video player configuration
//  error". Handing WKWebView a synthesised document instead does not help
//  either: `loadHTMLString` and `loadSimulatedRequest` both produce an opaque
//  origin, which the player rejects with error 152.
//
//  So the host page needs a real origin, and the cheapest real origin is a
//  loopback one. The page is served from 127.0.0.1, the iframe inside it is a
//  genuine youtube.com/embed URL with a matching `origin` parameter, and the
//  official IFrame Player API drives it. Playback stays entirely YouTube's:
//  view counts, ads and creator revenue are untouched.
//
//  ATS permits cleartext HTTP to loopback addresses, so this needs no
//  Info.plist exception.
//

import Foundation
import Network
import os

/// Lets exactly one caller through, from any thread.
private final class OnceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

actor LocalPlayerServer {
    static let shared = LocalPlayerServer()

    private var listener: NWListener?
    private var port: UInt16?
    private var starting: Task<UInt16?, Never>?

    private init() {}

    /// Returns the loopback port the host page is served on, starting the
    /// listener the first time it is asked. Concurrent callers share one start.
    func ensureRunning() async -> UInt16? {
        if let port { return port }
        if let starting { return await starting.value }

        let task = Task<UInt16?, Never> { [weak self] in
            await self?.startListener() ?? nil
        }
        starting = task
        let resolved = await task.value
        starting = nil
        return resolved
    }

    private func startListener() async -> UInt16? {
        do {
            let parameters = NWParameters.tcp
            // Deliberately NOT `acceptLocalOnly`: that flag means "local
            // network" and left loopback connections accepted by the kernel but
            // never handed to `newConnectionHandler`, so clients saw a reset.
            // Binding the local endpoint to 127.0.0.1 is what actually confines
            // this to loopback.
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)

            let listener = try NWListener(using: parameters)

            listener.newConnectionHandler = { connection in
                Self.serve(connection)
            }

            // `stateUpdateHandler` fires repeatedly; the continuation may only
            // be resumed once, and the handler runs off-actor.
            let once = OnceBox()
            let port: UInt16? = await withCheckedContinuation { continuation in
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if once.claim() { continuation.resume(returning: listener.port?.rawValue) }
                    case .failed, .cancelled:
                        if once.claim() { continuation.resume(returning: nil) }
                    default:
                        break
                    }
                }
                listener.start(queue: .global(qos: .userInitiated))
            }

            guard let port else {
                listener.cancel()
                return nil
            }
            self.listener = listener
            self.port = port
            return port
        } catch {
            return nil
        }
    }

    // MARK: - Connection handling

    /// The page is identical for every video — it reads the id and the initial
    /// play/mute state from its own query string — so the server can answer
    /// every request with one constant response and close.
    private nonisolated static func serve(_ connection: NWConnection) {
        // Only read once the connection is actually ready; receiving on a
        // pending connection is what left the client with a reset socket and
        // "The network connection was lost".
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                respond(on: connection)
            case .failed, .cancelled:
                connection.stateUpdateHandler = nil
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private nonisolated static func respond(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, _, error in
            guard error == nil else {
                connection.cancel()
                return
            }

            let body = Data(hostPage.utf8)
            // Built by concatenation rather than a multi-line literal so the
            // CRLFs stay exact no matter how the source is formatted.
            var response = Data(
                ("HTTP/1.1 200 OK\r\n"
                 + "Content-Type: text/html; charset=utf-8\r\n"
                 + "Content-Length: \(body.count)\r\n"
                 + "Cache-Control: no-store\r\n"
                 + "Connection: close\r\n\r\n").utf8
            )
            response.append(body)

            // `.finalMessage` + isComplete sends a FIN once the bytes are
            // written, so the client sees a clean end of stream instead of a
            // reset. Cancelling outright here truncates the response.
            connection.send(content: response,
                            contentContext: .finalMessage,
                            isComplete: true,
                            completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

// MARK: - Host page

extension LocalPlayerServer {
    /// The page the web view actually loads. It hosts a real youtube.com embed
    /// in an iframe and talks to it through the official IFrame Player API,
    /// bridging state back to Swift over `window.webkit.messageHandlers.player`.
    nonisolated static let hostPage = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
      <style>
        html, body { margin:0; padding:0; height:100%; background:#000; overflow:hidden; }

        /* The iframe is locked to 9:16 and sized to *fit* inside the viewport —
           `object-fit: contain`, done by hand because the video lives inside a
           cross-origin frame.

           This used to be `max()` rather than `min()`, i.e. cover, so that the
           clip reached every edge of a phone taller than 9:16. That crops, and
           it crops more the taller the phone: at 393×800 the iframe came out
           450 wide and lost 7% of the picture off each side. The player's own
           overlay is laid out across the iframe, not the screen, so the title
           and the action rail went off-screen with it. Letterboxing costs two
           bands of background and shows the whole frame; ShortCard already
           puts a blurred still behind the player for exactly that. */
        #player {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: min(100vw, calc(100vh * 9 / 16));
          height: min(100vh, calc(100vw * 16 / 9));
          border: 0;
        }
      </style>
    </head>
    <body>
      <div id="player"></div>
      <script>
        var params = new URLSearchParams(window.location.search);
        var videoID = params.get('v') || '';
        var wantsPlay = params.get('autoplay') === '1';
        var player = null;
        var hasPlayed = false;

        function post(payload) {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.player) {
            window.webkit.messageHandlers.player.postMessage(payload);
          }
        }

        // If the API script itself never arrives, nothing else will ever fire.
        window.addEventListener('error', function (e) {
          if (e.target && e.target.tagName === 'SCRIPT') { post({ type: 'error', code: -4 }); }
        }, true);

        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: videoID,
            host: 'https://www.youtube.com',
            playerVars: {
              playsinline: 1,
              // Always muted to start: the player applies its own mobile
              // autoplay rules and silently refuses to begin unmuted without a
              // gesture. Sound is restored from Swift once it is running.
              autoplay: wantsPlay ? 1 : 0,
              mute: 1,
              controls: 0,
              rel: 0,
              modestbranding: 1,
              fs: 0,
              disablekb: 1,
              iv_load_policy: 3,
              // Captions render across the bottom of the frame, which the card
              // now covers with its own title and gradient. Off by default.
              cc_load_policy: 0,
              enablejsapi: 1,
              origin: window.location.origin
            },
            events: {
              onReady: function (e) {
                e.target.mute();
                // `cc_load_policy` is only a default; a video whose track is
                // forced on ignores it, so turn the module off outright.
                if (e.target.unloadModule) { e.target.unloadModule('captions'); }
                if (e.target.unloadModule) { e.target.unloadModule('cc'); }
                post({ type: 'ready' });
                if (wantsPlay) { e.target.playVideo(); }
              },
              onStateChange: function (e) {
                if (e.data === YT.PlayerState.PLAYING) { hasPlayed = true; }
                post({ type: 'state', state: e.data });
                // Shorts loop. The loop param is unreliable for a single
                // video, so restart explicitly.
                if (e.data === YT.PlayerState.ENDED) { e.target.playVideo(); }
              },
              onError: function (e) { post({ type: 'error', code: e.data }); }
            }
          });
        }

        function scholarPlay() {
          wantsPlay = true;
          if (player && player.playVideo) { player.playVideo(); }
        }
        function scholarPause() {
          wantsPlay = false;
          if (player && player.pauseVideo) { player.pauseVideo(); }
        }
        function scholarMute(m) {
          if (!player) { return; }
          if (m) {
            player.mute();
            return;
          }
          player.unMute();
          // Unmuting without a gesture can get playback suspended outright.
          // Silence beats a frozen frame, so put it back if that happens.
          setTimeout(function () {
            if (wantsPlay && player.getPlayerState && player.getPlayerState() !== YT.PlayerState.PLAYING) {
              player.mute();
              post({ type: 'mutedfallback' });
              player.playVideo();
            }
          }, 500);
        }

        // A player that builds but never starts would otherwise hold a black
        // frame with nothing reported.
        setTimeout(function () {
          if (wantsPlay && !hasPlayed) {
            var state = (player && player.getPlayerState) ? player.getPlayerState() : 'none';
            post({ type: 'error', code: -7, detail: 'never started, state ' + state });
          }
        }, 12000);
      </script>
      <script src="https://www.youtube.com/iframe_api"></script>
    </body>
    </html>
    """
}

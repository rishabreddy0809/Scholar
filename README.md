# Scholar

**A short-form learning feed for iOS. Upload your lecture notes, get a scroll of educational Shorts and podcast episodes about exactly what you have to study.**

Scholar is the doomscrolling loop pointed at your syllabus. It has the same vertical, endless, one-thumb feel as any short-video app — but the feed is built from your own study material, and every card is filtered against it.

There is no backend, no account, and no API key. The app runs on public feeds and everything about you — your notes, your progress, your taste — stays on the device.

---

## What it does

**Study mode.** Import a lecture PDF, photograph your handwritten notes, or paste text. Scholar extracts the text on device, works out what the document is about, and rebuilds the Feed and Listen tabs around it. Content that doesn't demonstrably match the document is dropped rather than demoted.

**Feed.** A full-screen vertical scroll of educational YouTube Shorts. Swipe, double-tap to like, save for later. The feed never hits a bottom: sources are pulled in waves and round-robin interleaved so you never get five clips from one channel in a row, and once every source is spent the corpus reshuffles with unseen items first.

**Listen.** The same feed shape for podcasts, backed by a real AVPlayer with lock screen and Control Center controls. Pin an episode and it keeps playing in a mini player while you browse.

**Topics.** Twenty-eight interests across six categories. Pick as many as you like and the everyday feed follows them. A dashboard tracks a daily study-minutes goal, a streak, and per-topic progress.

**Generate.** Type a topic and Scholar builds a feed for it. Paste a YouTube channel link or a podcast RSS URL and it adds that source directly.

---

## How it works

The interesting parts are the ones that avoid needing a server.

### Content, without an API key

| Source | Mechanism |
| --- | --- |
| YouTube Shorts | Public Atom feeds. YouTube exposes a Shorts-only playlist per channel by swapping the `UC` channel prefix for `UUSH` — no key, no quota. |
| Podcast discovery | The public iTunes Search directory: real full-text search, no key. |
| Episodes | Each show's own RSS feed. |

Every channel in the catalogue was verified against its Shorts playlist before being added; ones whose Shorts shelf came back empty were dropped.

### Playing a Short without touching the media stream

Playback goes through YouTube's own embed, so view counts, ads and creator revenue stay intact. Getting that to work inside a `WKWebView` took a loopback HTTP server, and the reason is documented at length in `LocalPlayerServer.swift`:

- Navigating straight to `youtube.com/embed/<id>` gives the player no host page — no referrer, no ancestor origin — and it refuses with **error 153**. The `/embed/` endpoint is built to be framed, not visited.
- Handing the web view a synthesised document via `loadHTMLString` or `loadSimulatedRequest` produces an **opaque origin**, which the player rejects with **error 152**.

So the app serves a real host page from `127.0.0.1` using `Network.framework`, embeds a genuine `youtube.com/embed` iframe inside it with a matching `origin` parameter, and drives it through the official IFrame Player API. A loopback origin is a real origin, which satisfies both checks. ATS already permits cleartext HTTP to loopback, so this needs no `Info.plist` exception.

### Reading your notes

All on device, nothing uploaded:

- **PDFKit** for documents (capped at 40 pages, which is far more than the extractor needs and keeps a 500-page textbook from stalling the import).
- **Vision** `VNRecognizeTextRequest` on the accurate path with language correction, for photographed slides and reasonably tidy handwriting.
- **NaturalLanguage** for keyword extraction — lemmatisation, stop-word removal, named-entity detection, repeated bigrams, and capitalised proper phrases weighted hard, because a bag of single words turns a document about the American Revolution into a search for "army".

### Classifying it strictly

Subject matching is the part most likely to embarrass a feed app, so it is deliberately conservative. Two rules do the work:

**Anchors versus keywords.** Each interest carries *anchor* terms that only ever mean that subject (`neurotransmitter`, `hippocampus`, `stoichiometr`) separately from shared vocabulary (`memory`, `neural`, `learning`, `model`). A subject cannot be assigned unless an anchor names it; shared words only corroborate. Most of a subject's obvious vocabulary belongs to three other subjects at once, and scoring it flat is how a document about training on-device models gets filed under Neuroscience.

**Longest phrase wins the span.** Matching runs on word-boundary tokens, and when several catalogue terms cover the same run of text the longest one takes it outright. `neural network` is an AI anchor, so it consumes both tokens and Neuroscience never sees the word `neural` at all. Same for `machine learning` against Education, and `training data` against everything.

On top of that: a subject needs two distinct anchors, or one said three times. At most two tags survive, and only within 55% of the winner's score. When nothing clears the bar the document gets **no tag** — a wrong tag puts a whole subject's channels behind the study feed, which is worse than none.

```
Cellular respiration notes      → Biology
American Revolution notes       → History
On-device ML training notes     → AI & Tech
Biologically-inspired learning  → AI & Tech, Neuroscience
A recipe                        → (none)
```

Materials store the extractor version that produced their keywords, so improving extraction re-derives everything already in the library instead of leaving it with stale topics.

---

## Project layout

```
Scholar/
├── Core/          Models, Store (all persistence), Interest catalogue, theme, shared views
├── Feed/          Paging feed, short card, feed engine, YouTube player
├── Listen/        Audio engine, podcast card, episode browser, mini player
├── Study/         Import, text extraction, keyword extraction, StudyMaterial
├── Topics/        Dashboard, interest grid, onboarding
├── Generate/      Build-a-feed-from-a-topic flow
├── Library/       Saved items
├── Networking/    YouTube Atom, iTunes/RSS, local player server, channel catalogue
└── Helpers/       Morphing tab bar
```

Roughly 6,700 lines of Swift.

---

## Building

Open `Scholar.xcodeproj` and run. There is nothing to configure.

- **Xcode** with an iOS 26.5 SDK
- **iOS 26.5+**, iPhone and iPad
- **No dependencies** — no SPM packages, no CocoaPods, no Carthage
- SwiftUI throughout, `@Observable` for state, Swift 5 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

You will need to set your own development team to run on a physical device.

Shorts play fine in the Simulator, contrary to the usual folklore — only the bare `/embed/` URL fails there, for the origin reasons above.

---

## Privacy

Everything is local. Votes, saves, seen items, per-topic progress, the streak, and imported study materials all live in `UserDefaults` on the device. There is no analytics, no account system, no server owned by this project, and no upload path for your notes. Network traffic goes to YouTube, the iTunes directory, and podcast RSS hosts — the same places a browser would go.

---

## Status

Personal project, version 1.0, actively being built. Rough edges worth knowing:

- The channel catalogue is hand-curated and English-language.
- Strict classification trades recall for precision by design — a study feed can run thin on a narrow topic, because YouTube's Shorts feed only exposes each channel's ~15 most recent clips.
- No test target yet.

## License

Not yet licensed. All rights reserved for now.

//
//  ChannelCatalog.swift
//  Scholar
//
//  Every channel ID below was verified against YouTube's Shorts-only playlist
//  feed (playlist `UUSH` + channel suffix) before being added. Channels whose
//  Shorts shelf came back empty were dropped, so each entry here is a live
//  source of short-form content rather than a long-form back catalogue.
//

import Foundation

nonisolated struct EduChannel: Identifiable, Hashable, Codable, Sendable {
    let id: String          // "UC..." channel identifier
    let name: String

    /// YouTube exposes a per-channel Shorts playlist by swapping the "UC"
    /// prefix for "UUSH". This is a public Atom feed: no API key, no quota.
    var shortsPlaylistID: String { "UUSH" + id.dropFirst(2) }

    var shortsFeedURL: URL? {
        URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(shortsPlaylistID)")
    }

    /// The channel's regular uploads feed, used when a channel is added by
    /// link and turns out to have no Shorts shelf.
    var uploadsFeedURL: URL? {
        URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(id)")
    }
}

nonisolated enum ChannelCatalog {
    static let kurzgesagt      = EduChannel(id: "UCsXVk37bltHxD1rDPwtNM8Q", name: "Kurzgesagt")
    static let veritasium      = EduChannel(id: "UCHnyfMqiRRG1u-2MsSQLbXA", name: "Veritasium")
    static let sciShow         = EduChannel(id: "UCZYTClx2T1of7BRZ86-8fow", name: "SciShow")
    static let asapScience     = EduChannel(id: "UCC552Sd-3nyi_tk2BudLUzA", name: "AsapSCIENCE")
    static let steveMould      = EduChannel(id: "UCEIwxahdLz7bap-VDs9h35A", name: "Steve Mould")
    static let minutePhysics   = EduChannel(id: "UCUHW94eEFW7hkUMVaZz4eDg", name: "minutephysics")
    static let actionLab       = EduChannel(id: "UC1VLQPn9cYSqx8plbk9RxxQ", name: "The Action Lab")
    static let markRober       = EduChannel(id: "UCY1kMZp36IQSyNx_9h4mpCg", name: "Mark Rober")
    static let vsauce          = EduChannel(id: "UC6nSFpj9HTCZ5t-N3Rm3-HA", name: "Vsauce")
    static let beSmart         = EduChannel(id: "UCH4BNI0-FOK2dMXoFtViWHw", name: "Be Smart")
    static let scienceABC      = EduChannel(id: "UCcN3IuIAR6Fn74FWMQf6lFA", name: "Science ABC")
    static let seeker          = EduChannel(id: "UCzWQYUVCpZqtN93H8RR44Qw", name: "Seeker")
    static let howStuffWorks   = EduChannel(id: "UCa35qyNpnlZ_u8n9qoAZbMQ", name: "HowStuffWorks")
    static let realScience     = EduChannel(id: "UC176GAQozKKjhz62H8u9vQQ", name: "Real Science")
    static let tedEd           = EduChannel(id: "UCsooa4yRKGN_zEE8iknghZA", name: "TED-Ed")
    static let ted             = EduChannel(id: "UCAuUUnT6oDeKwE6v1NGQxug", name: "TED")
    static let zackDFilms      = EduChannel(id: "UCvz84_Q0BbvZThy75mbd-Dg", name: "Zack D. Films")
    static let threeBlueOneBrown = EduChannel(id: "UCYO_jab_esuFRV4b17AJtAw", name: "3Blue1Brown")
    static let numberphile     = EduChannel(id: "UCoxcjq-8xIDTYp3uz647V5A", name: "Numberphile")
    static let nasa            = EduChannel(id: "UCLA_DiR1FfKNvjuUpBHmylQ", name: "NASA")
    static let astrum          = EduChannel(id: "UC-9b7aDP6ZN0coj9-xFnrtw", name: "Astrum")
    static let simpleHistory   = EduChannel(id: "UC510QYlOlKNyhy_zdQxnGYw", name: "Simple History")
    static let knowledgia      = EduChannel(id: "UCuCuEKq1xuRA0dFQj1qg9-Q", name: "Knowledgia")
    static let historyMatters  = EduChannel(id: "UC22BdTgxefuvUivrjesETjg", name: "History Matters")
    static let fireship        = EduChannel(id: "UCsBjURrPoezykLs9EqgamOA", name: "Fireship")
    static let realEngineering = EduChannel(id: "UCR1IuLEqb6UEA_zQ81kwXfg", name: "Real Engineering")
    static let osmosis         = EduChannel(id: "UCNI0qOojpkhsUtaQ4_2NUhQ", name: "Osmosis")
    static let tierZoo         = EduChannel(id: "UCHsRtomD4twRf5WVHHk-cMw", name: "TierZoo")
    static let bbcEarth        = EduChannel(id: "UCwmZiChSryoWQCZMIQezgTg", name: "BBC Earth")
    static let natGeo          = EduChannel(id: "UCpVm7bg6pXKo1Pr6k5kxG9A", name: "National Geographic")
    static let minuteEarth     = EduChannel(id: "UCeiYXex_fwgYDonaTcSIk6w", name: "MinuteEarth")
    static let nileRed         = EduChannel(id: "UCFhXFikryT4aFcLkLw2LBLA", name: "NileRed")
    static let periodicVideos  = EduChannel(id: "UCtESv1e7ntJaLJYKIO1FoYw", name: "Periodic Videos")
    static let psych2Go        = EduChannel(id: "UCkJEpR7JmS36tajD34Gp4VA", name: "Psych2Go")
    static let sprouts         = EduChannel(id: "UC-RKpEc4eE9PwJaupN91xYQ", name: "Sprouts")
    static let economicsExplained = EduChannel(id: "UCZ4AMrDcNrfy3X6nsU8-rPg", name: "Economics Explained")
    static let twoCents        = EduChannel(id: "UCL8w_A8p8P1HWI3k6PR5Z6w", name: "Two Cents")
    static let langfocus       = EduChannel(id: "UCNhX3WQEkraW3VHPyup8jkQ", name: "Langfocus")
    static let geographyNow    = EduChannel(id: "UCmmPgObSUPw1HL2lq6H4ffA", name: "Geography Now")
    static let schoolOfLife    = EduChannel(id: "UC7IcJI8PUf5Z3zKxnZvTBog", name: "The School of Life")

    static let all: [EduChannel] = [
        kurzgesagt, veritasium, sciShow, asapScience, steveMould, minutePhysics,
        actionLab, markRober, vsauce, beSmart, scienceABC, seeker, howStuffWorks,
        realScience, tedEd, ted, zackDFilms, threeBlueOneBrown, numberphile, nasa,
        astrum, simpleHistory, knowledgia, historyMatters, fireship, realEngineering,
        osmosis, tierZoo, bbcEarth, natGeo, minuteEarth, nileRed, periodicVideos,
        psych2Go, sprouts, economicsExplained, twoCents, langfocus, geographyNow,
        schoolOfLife
    ]

    static func channel(id: String) -> EduChannel? {
        all.first { $0.id == id }
    }
}

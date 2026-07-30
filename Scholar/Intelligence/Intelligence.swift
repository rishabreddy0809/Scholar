//
//  Intelligence.swift
//  Scholar
//
//  Availability gate for Apple's on-device foundation model.
//
//  `SystemLanguageModel` is the local model that ships with Apple Intelligence.
//  It runs entirely on the device — no Private Cloud Compute, no network — which
//  is the only reason it is allowed anywhere near a student's notes.
//
//  Nothing in the app may depend on it. It is missing on older hardware, off
//  until the user enables Apple Intelligence, absent while the assets are still
//  downloading, and unsupported in most locales. Every caller therefore treats
//  a model answer as an upgrade over the deterministic path in KeywordExtractor,
//  never as a replacement for it.
//

import FoundationModels

nonisolated enum Intelligence {

    enum Availability: Equatable {
        case ready
        case noHardware
        case turnedOff
        case downloading
        case unsupportedLanguage

        var isReady: Bool { self == .ready }

        /// One line, phrased for a hint under an import button. `nil` when the
        /// model is working and there is nothing to explain.
        var hint: String? {
            switch self {
            case .ready:
                return nil
            case .noHardware:
                return "This device doesn't support Apple Intelligence. Topics are matched with the built-in catalogue instead."
            case .turnedOff:
                return "Turn on Apple Intelligence in Settings for sharper topic matching."
            case .downloading:
                return "Apple Intelligence is still downloading. Topics are matched with the built-in catalogue for now."
            case .unsupportedLanguage:
                return "Apple Intelligence doesn't cover this language yet. Topics are matched with the built-in catalogue."
            }
        }
    }

    static var availability: Availability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            // Availability is about the assets; the locale check is separate,
            // and asking in an unsupported language throws mid-generation.
            return model.supportsLocale() ? .ready : .unsupportedLanguage
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:          return .noHardware
            case .appleIntelligenceNotEnabled: return .turnedOff
            case .modelNotReady:              return .downloading
            @unknown default:                 return .noHardware
            }
        }
    }

    static var isReady: Bool { availability.isReady }
}
